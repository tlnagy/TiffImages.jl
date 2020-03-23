"""
    TiffFile(io) -> TiffFile

Wrap `io` with helper parameters to keep track of file attributes.
"""
mutable struct TiffFile{O <: Unsigned}
    """The relative path to this file"""
    filepath::String

    """The file stream"""
    io::Stream

    """Location of the first IFD in the file stream"""
    first_offset::Int

    """Whether this file has a different endianness than the host computer"""
    need_bswap::Bool

    function TiffFile(io::Stream)
        seekstart(io)
        filepath = extract_filename(io)
        bs = need_bswap(io)
        offset_size = offsetsize(io)
        first_offset_raw = read(io, offset_size)
        first_offset = Int(bs ? bswap(first_offset_raw) : first_offset_raw)
        new{offset_size}(filepath, io, first_offset, bs)
    end
end

TiffFile(io::IOStream) = TiffFile(Stream(format"TIFF", io, extract_filename(io)))

"""
    offset(file)

Returns the type of the TIFF file offset. For most TIFFs, it should be UInt32,
while for BigTIFFs it will be UInt64.
"""
offset(file::TiffFile{O}) where {O} = O

function Base.read(file::TiffFile{O}, ::Type{T}) where {O, T}
    value = read(file.io, T)
    file.need_bswap ? bswap(value) : value
end

function Base.read(file::TiffFile{O}, ::Type{String}) where O
    value = read(file.io, O)
    file.need_bswap ? bswap(value) : value
end

function Base.read!(file::TiffFile, arr::AbstractArray)
    read!(stream(file.io), arr)
    if file.need_bswap
        arr .= bswap.(arr)
    end
end

function Base.read!(io::IOStream, arr::SubArray{T,N,P,I,L}) where {T, N, P <: BitArray, I <: Tuple{UnitRange, Int64}, L}
    error("Strided bilevel TIFFs are not yet supported. Please open an issue against TIFF.jl.")
end

function Base.read!(io::IOStream, arr::SubArray{T,N,P,I,L}) where {T, N, P <: BitArray, I <: Tuple{Base.Slice, Int64}, L}
    rng = arr.offset1 .+ arr.indices[1]
    n = length(rng)
    Bc = view(parent(arr).chunks, (Base.get_chunks_id(rng.start)[1]):(Base.get_chunks_id(rng.stop)[1]))
    nc = length(read!(io, Bc))
    if length(Bc) > 0 && Bc[end] & Base._msk_end(n) ≠ Bc[end]
        Bc[end] &= Base._msk_end(n) # ensure that the BitArray is not broken
    end
    for i in 1:nc
       Bc[i] = TIFF.reversebits(Bc[i]) 
    end
    arr
end

Base.seek(file::TiffFile, n::Integer) = seek(file.io, n)

Base.bswap(x::Rational{T}) where {T} = Rational(bswap(x.num), bswap(x.den))

Base.IteratorSize(::TiffFile) = Base.SizeUnknown()