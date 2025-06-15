
function Base.read!(tfs::TiffFileStrip{S}, arr::AbstractVector{UInt8}, ::Val{COMPRESSION_CCITT_T6}) where S
	input::Vector{UInt8} = Vector{UInt8}(undef, bytesavailable(tfs))
	read!(tfs, input)	
	t6_decode!(input, TiffImages.ncols(tfs.ifd), TiffImages.getdata(Int, tfs.ifd, TiffImages.ROWSPERSTRIP, -1), arr)
end

struct T6Code{N}
	code::UInt8
end

function checkbits(x::UInt16, y::T6Code{N}) where N
	return x >>(16-N) == y.code
end

function getcodelength(y::T6Code{N}) where N
	return N
end

T6CODE_V0 = T6Code{1}(0b1)
T6CODE_VR1 = T6Code{3}(0b011)
T6CODE_VL1 = T6Code{3}(0b010)
T6CODE_HOR = T6Code{3}(0b001)
T6CODE_PAS = T6Code{4}(0b0001)
T6CODE_VR2 = T6Code{6}(0b000011)
T6CODE_VL2 = T6Code{6}(0b000010)
T6CODE_VR3 = T6Code{7}(0b0000011)
T6CODE_VL3 = T6Code{7}(0b0000010)
T6CODE_EXT = T6Code{8}(0b00000001)
T6CODE_END = T6Code{12}(0b000000000001)

struct Leaf
	bits::Int
	encoded_pixel_count::Int
end

struct Node
	children::NTuple{4, Union{Node, Leaf, Nothing}}
end

const VCodeTree = Node((
	Node((
		Node((
			nothing,
			Node((
				Leaf(7,-3),Leaf(7,-3),Leaf(7,3),Leaf(7,3))),
			Leaf(6,-2),
			Leaf(6, 2))),
		nothing,
		nothing,
		nothing
	)),
	Node((Leaf(3, -1), Leaf(3, -1), Leaf(3, 1), Leaf(3, 1))),
	Leaf(1,0),
	Leaf(1,0)
))

function getoffset(code::UInt16)
	return getnodeval(VCodeTree, code)
end

struct PixelColor
	white::Bool
end
const Black = PixelColor(0)
const White = PixelColor(1)
Base.:!(x::PixelColor) = x == White ? Black : White
Base.convert(::Type{Bool}, x::PixelColor) = x.white

function iteratebits(input::AbstractVector{UInt8}, state, bitcount::Int)::Union{Nothing, Tuple{UInt16, Any}}
	if state.input_offset == length(input) && state.remainingbitcount < bitcount
		return nothing
	end
	offset = state.input_offset
	remainingbitcount = state.remainingbitcount - bitcount
	bitbuffer = state.bitbuffer
	while remainingbitcount < 16
		if offset < length(input)
			bitbuffer = bitbuffer << 8 | input[offset += 1]
		else
			break
		end
		remainingbitcount += 8
	end
	if remainingbitcount >= 16
		return (UInt16(bitbuffer >> (remainingbitcount - 16) & 0xFFFF), (remainingbitcount = remainingbitcount, bitbuffer = bitbuffer, input_offset = offset))
	else
		return (UInt16(bitbuffer << (16 - remainingbitcount) & 0xFFFF), (remainingbitcount = remainingbitcount, bitbuffer = bitbuffer, input_offset = offset))
	end
end
function iteratebits(input::AbstractVector{UInt8})::Union{Nothing, Tuple{UInt16, Any}}
	return iteratebits(input, (remainingbitcount = 0, bitbuffer = 0, input_offset = 0), 0)
end


function summakeupcodes(next_code, iter_state, iteratorinput::AbstractVector{UInt8}, pixelcolor::PixelColor)
	m = getmatch(pixelcolor, next_code)
	len = 0
	while m.encoded_pixel_count >= 64
		len += m.encoded_pixel_count
		next_code, iter_state = iteratebits(iteratorinput, iter_state, m.bits)
		m = getmatch(pixelcolor, next_code)
	end
	len += m.encoded_pixel_count
	next_code, iter_state = iteratebits(iteratorinput, iter_state, m.bits)
	return (len, m, next_code, iter_state)
end

function findnextcolor(arr::Nothing, start::Int, chunk_ncols::Int, pixelcolor::PixelColor) :: Int
	@debug "findnextcolor $(pixelcolor == White ? "white" : "black") from $start (nothing)"
	return chunk_ncols + 1
end
function findnextcolor(ar::AbstractVector{Bool}, offset::Int, pixelcolor::PixelColor)
	return Base.findnext(==(convert(Bool, pixelcolor)), ar, offset)
end
function findnextcolor(ar::AbstractVector{Bool}, offset::Int, unused, pixelcolor::PixelColor)
	return Base.findnext(==(convert(Bool, pixelcolor)), ar, offset)
end

function findnextchangeto(arr::Nothing, start::Int, chunk_ncols::Int, pixelcolor::PixelColor) :: Int
	@debug "findnextchangeto $(pixelcolor == White ? "white" : "black") from $start (nothing)"
	return chunk_ncols + 1
end
function findnextchangeto(arr::AbstractVector{Bool}, start::Int, chunk_ncols::Int, pixelcolor::PixelColor) :: Int
	@debug "findnextchangeto $(pixelcolor == White ? "white" : "black") from $start"
	if start <= 0
		# fake line is all white
		return chunk_ncols + 1
	end
	if start % chunk_ncols == 1 && !(pixelcolor == White) && findnextcolor(arr, start, chunk_ncols, pixelcolor) == start
		@debug "early return"
		return start
	end
	next_start = findnextcolor(arr, start, chunk_ncols, !pixelcolor)
	if next_start == chunk_ncols + 1
		return next_start
	end
	if next_start == nothing
		# needed sometimes when second change is end
		return chunk_ncols + 1
	end
	ret = findnextcolor(arr, next_start, chunk_ncols, pixelcolor)
	if ret == nothing
		return chunk_ncols + 1
	end
	return ret
end

function colorpixels(ar::AbstractVector{Bool}, offset::Int, len::Int, pixelcolor::PixelColor)
	@debug "colorpixels offset $offset, len $len, paint $(pixelcolor == White ? "white" : "black")"
	if len > 0
		ar[offset : offset + len - 1] .= convert(Bool, pixelcolor)
	end
end

function t6_decode!(input::Vector{UInt8}, chunk_ncols, chunk_nrows, arr::AbstractVector{UInt8})
	@debug "Reading element of size $chunk_ncols x $chunk_nrows"
	pixelcolor = White
	
	# sometimes the last chunk length does not match
	if (length(arr)!= chunk_ncols * chunk_nrows)
		@warn "Trying to fix number of rows..."
		chunk_nrows = div(length(arr), chunk_ncols)
	end
	
	ar2 = BitArray(undef,(chunk_ncols, chunk_nrows)) # column-major
	ar2 .= false
	curr_row = 1
	curr_col = 1
	prev_col = 1
	
	next_code, iter_state = iteratebits(input)
	max_iterations = 8 * length(input)
	
	for j in (1:max_iterations)
		
		prev_arr = curr_row > 1 ? @view(ar2[:,curr_row - 1]) : nothing
		curr_arr = curr_row <= chunk_nrows ? @view(ar2[:,curr_row]) : nothing
		if checkbits(next_code, T6CODE_HOR)
			@debug "T6CODE_HOR"
			codelen = getcodelength(T6CODE_HOR)
			next_code, iter_state = iteratebits(input, iter_state, codelen)
			(len, m, next_code, iter_state) = summakeupcodes(next_code, iter_state, input, pixelcolor)
			colorpixels(curr_arr, curr_col, len, pixelcolor)
			curr_col += len
			(len, m, next_code, iter_state) = summakeupcodes(next_code, iter_state, input, !pixelcolor)
			colorpixels(curr_arr, curr_col, len, !pixelcolor)
			curr_col += len
			prev_col = curr_col
		
		elseif checkbits(next_code, T6CODE_PAS)
			@debug "T6CODE_PAS"
			# skip if looking at the beginning of the row
			if prev_col > 1
				b1 = findnextcolor(prev_arr, curr_col, pixelcolor)
				colorpixels(curr_arr, curr_col, b1 - curr_col, pixelcolor)
				curr_col += b1 - curr_col
			end
			b1 = findnextcolor(prev_arr, curr_col, !pixelcolor)
			colorpixels(curr_arr, curr_col, b1 - curr_col, pixelcolor)
			curr_col += b1 - curr_col

			b1 = findnextcolor(prev_arr, curr_col, pixelcolor)
			colorpixels(curr_arr, curr_col, b1 - curr_col, pixelcolor)
			curr_col += b1 - curr_col
			prev_col = curr_col
			
			codelen = getcodelength(T6CODE_PAS)
			next_code, iter_state = iteratebits(input, iter_state, codelen)
		
		elseif checkbits(next_code, T6CODE_END)
			codelen = getcodelength(T6CODE_END)
			next_code, iter_state = iteratebits(input, iter_state, codelen)
			@assert(checkbits(next_code, T6CODE_END))
			break
		else
			bitsandval = getoffset(next_code)
			if bitsandval == nothing
				error("Unknown code: ", bitstring(next_code))
			end
			@debug "T6CODE_V $(bitsandval.encoded_pixel_count)"
			codelen = bitsandval.bits

			nextidx = findnextchangeto(prev_arr, curr_col, chunk_ncols, !pixelcolor)
			
			b1 = nextidx + bitsandval.encoded_pixel_count
			colorpixels(curr_arr, curr_col, b1 - curr_col, pixelcolor)
			curr_col += b1 - curr_col
			prev_col = nextidx
			
			next_code, iter_state = iteratebits(input, iter_state, codelen)
			pixelcolor = !pixelcolor
			
		end
		
		if curr_col == chunk_ncols + 1
			curr_col = 1
			prev_col = 1
			curr_row += 1
			pixelcolor = White
			@debug("Next row: $curr_row")
		end
	end
	
	arr .= reshape(UInt8.(ar2),:)
	
	if curr_col != 1 || curr_row != chunk_nrows + 1
		@warn (curr_col, curr_row) (chunk_ncols, chunk_nrows)
	end
end

struct NKV
	n::Int
	k::Int
	v::Int
end

function NKV(bitcode::String, encoded_value::Int)
	return NKV(length(bitcode), parse(Int, bitcode, base=2) << (16 - length(bitcode)), encoded_value)
end

const CodesWhite = [
NKV("00110101", 0),
NKV("000111", 1),
NKV("0111", 2),
NKV("1000", 3),
NKV("1011", 4),
NKV("1100", 5),
NKV("1110", 6),
NKV("1111", 7),
NKV("10011", 8),
NKV("10100", 9),
NKV("00111", 10),
NKV("01000", 11),
NKV("001000", 12),
NKV("000011", 13),
NKV("110100", 14),
NKV("110101", 15),
NKV("101010", 16),
NKV("101011", 17),
NKV("0100111", 18),
NKV("0001100", 19),
NKV("0001000", 20),
NKV("0010111", 21),
NKV("0000011", 22),
NKV("0000100", 23),
NKV("0101000", 24),
NKV("0101011", 25),
NKV("0010011", 26),
NKV("0100100", 27),
NKV("0011000", 28),
NKV("00000010", 29),
NKV("00000011", 30),
NKV("00011010", 31),
NKV("00011011", 32),
NKV("00010010", 33),
NKV("00010011", 34),
NKV("00010100", 35),
NKV("00010101", 36),
NKV("00010110", 37),
NKV("00010111", 38),
NKV("00101000", 39),
NKV("00101001", 40),
NKV("00101010", 41),
NKV("00101011", 42),
NKV("00101100", 43),
NKV("00101101", 44),
NKV("00000100", 45),
NKV("00000101", 46),
NKV("00001010", 47),
NKV("00001011", 48),
NKV("01010010", 49),
NKV("01010011", 50),
NKV("01010100", 51),
NKV("01010101", 52),
NKV("00100100", 53),
NKV("00100101", 54),
NKV("01011000", 55),
NKV("01011001", 56),
NKV("01011010", 57),
NKV("01011011", 58),
NKV("01001010", 59),
NKV("01001011", 60),
NKV("00110010", 61),
NKV("00110011", 62),
NKV("00110100", 63),
NKV("11011", 64),
NKV("10010", 128),
NKV("010111", 192),
NKV("0110111", 256),
NKV("00110110", 320),
NKV("00110111", 384),
NKV("01100100", 448),
NKV("01100101", 512),
NKV("01101000", 576),
NKV("01100111", 640),
NKV("011001100", 704),
NKV("011001101", 768),
NKV("011010010", 832),
NKV("011010011", 896),
NKV("011010100", 960),
NKV("011010101", 1024),
NKV("011010110", 1088),
NKV("011010111", 1152),
NKV("011011000", 1216),
NKV("011011001", 1280),
NKV("011011010", 1344),
NKV("011011011", 1408),
NKV("010011000", 1472),
NKV("010011001", 1536),
NKV("010011010", 1600),
NKV("011000", 1664),
NKV("010011011", 1728)
]

const CodesBlack = [
NKV("0000110111", 0),
NKV("010", 1),
NKV("11", 2),
NKV("10", 3),
NKV("011", 4),
NKV("0011", 5),
NKV("0010", 6),
NKV("00011", 7),
NKV("000101", 8),
NKV("000100", 9),
NKV("0000100", 10),
NKV("0000101", 11),
NKV("0000111", 12),
NKV("00000100", 13),
NKV("00000111", 14),
NKV("000011000", 15),
NKV("0000010111", 16),
NKV("0000011000", 17),
NKV("0000001000", 18),
NKV("00001100111", 19),
NKV("00001101000", 20),
NKV("00001101100", 21),
NKV("00000110111", 22),
NKV("00000101000", 23),
NKV("00000010111", 24),
NKV("00000011000", 25),
NKV("000011001010", 26),
NKV("000011001011", 27),
NKV("000011001100", 28),
NKV("000011001101", 29),
NKV("000001101000", 30),
NKV("000001101001", 31),
NKV("000001101010", 32),
NKV("000001101011", 33),
NKV("000011010010", 34),
NKV("000011010011", 35),
NKV("000011010100", 36),
NKV("000011010101", 37),
NKV("000011010110", 38),
NKV("000011010111", 39),
NKV("000001101100", 40),
NKV("000001101101", 41),
NKV("000011011010", 42),
NKV("000011011011", 43),
NKV("000001010100", 44),
NKV("000001010101", 45),
NKV("000001010110", 46),
NKV("000001010111", 47),
NKV("000001100100", 48),
NKV("000001100101", 49),
NKV("000001010010", 50),
NKV("000001010011", 51),
NKV("000000100100", 52),
NKV("000000110111", 53),
NKV("000000111000", 54),
NKV("000000100111", 55),
NKV("000000101000", 56),
NKV("000001011000", 57),
NKV("000001011001", 58),
NKV("000000101011", 59),
NKV("000000101100", 60),
NKV("000001011010", 61),
NKV("000001100110", 62),
NKV("000001100111", 63),
NKV("0000001111", 64),
NKV("000011001000", 128),
NKV("000011001001", 192),
NKV("000001011011", 256),
NKV("000000110011", 320),
NKV("000000110100", 384),
NKV("000000110101", 448),
NKV("0000001101100", 512),
NKV("0000001101101", 576),
NKV("0000001001010", 640),
NKV("0000001001011", 704),
NKV("0000001001100", 768),
NKV("0000001001101", 832),
NKV("0000001110010", 896),
NKV("0000001110011", 960),
NKV("0000001110100", 1024),
NKV("0000001110101", 1088),
NKV("0000001110110", 1152),
NKV("0000001110111", 1216),
NKV("0000001010010", 1280),
NKV("0000001010011", 1344),
NKV("0000001010100", 1408),
NKV("0000001010101", 1472),
NKV("0000001011010", 1536),
NKV("0000001011011", 1600),
NKV("0000001100100", 1664),
NKV("0000001100101", 1728)
]
const CodesBoth = [
NKV("00000001000", 1792),
NKV("00000001100", 1856),
NKV("00000001101", 1920),
NKV("000000010010", 1984),
NKV("000000010011", 2048),
NKV("000000010100", 2112),
NKV("000000010101", 2176),
NKV("000000010110", 2240),
NKV("000000010111", 2304),
NKV("000000011100", 2368),
NKV("000000011101", 2432),
NKV("000000011110", 2496),
NKV("000000011111", 2560)
]

function getnodeval(node::Node, x::UInt16)
	s = x >> 14
	child = node.children[s + 1]
	if child isa Leaf
		return child
	end
	if child == nothing
		return nothing
	end
	return getnodeval(child, (x & 0x3FFF) << 2)
end


function matchone(nkv::NKV, m::Int, q::Int)
	return UInt16(nkv.k) >> (15 - m) & 0x1 == q
end
function matchtwo(nkv::NKV, m::Int, q::Int)
	return UInt16(nkv.k) >> (14 - m) & 0x3 == q
end

# n: level
# m: range start
function makenode(n::Int, m, ts::AbstractVector{NKV})
	if length(ts) == 0
		return nothing
	end
	n1_1or2 = ts |> filter(nkv -> nkv.n == n + 1 && matchone(nkv, n, 0))
	n1_3or4 = ts |> filter(nkv -> nkv.n == n + 1 && matchone(nkv, n, 1))
	n2 = map(x -> (ts |> filter(nkv -> nkv.n == n + 2 && matchtwo(nkv, n, x))), 0:3)

	if length(n1_1or2) > 0
		n2[1:2] = [n1_1or2, n1_1or2]
	end
	if length(n1_3or4) > 0
		n2[3:4] = [n1_3or4, n1_3or4]
	end
	return Node(
		NTuple{4, Union{Node, Leaf, Nothing}}(
			map(((i, x),) -> length(x) > 0 ? Leaf(only(x).n, only(x).v) : makenode(n+2, m + (i-1) << (14-n), ts |> filter(nkv -> nkv.k >= m + (i-1) << (14-n) && nkv.k < m + i << (14-n) - 1)), enumerate(n2))
		)
	)
end

function collectnodes(n::Int, ts)
	m = maximum(x -> typeof(x).parameters[1], ts)
	if m < n
		error("n is too large!")
	end
	
	t_m = filter(x -> typeof(x).parameters[1] == n, ts)
	leaves = Dict{Int, NTuple{4, Union{Int, Nothing}}}()
	
end

BlackTree = makenode(0, 0, vcat(CodesBlack, CodesBoth))
WhiteTree = makenode(0, 0, vcat(CodesWhite, CodesBoth))

function getmatch(pixelcolor::PixelColor, x::UInt16)
	if pixelcolor == White
		return getnodeval(WhiteTree, x)
	else
		return getnodeval(BlackTree, x)
	end
end
