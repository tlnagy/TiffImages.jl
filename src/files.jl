"""
    $(TYPEDEF) -> TiffFile

Wrap `io` with helper parameters to keep track of file attributes.

$(FIELDS)
"""
mutable struct TiffFile{O <: Unsigned, S <: Stream}
    """A unique identifier for this file"""
    uuid::Union{UUID, Nothing}

    """The relative path to this file"""
    filepath::String

    """The file stream"""
    io::S

    """Location of the first IFD in the file stream"""
    first_offset::Int

    """Whether this file has a different endianness than the host computer"""
    need_bswap::Bool
end

TiffFile{O}(s::Stream) where O <: Unsigned = TiffFile{O, typeof(s)}(nothing, "", s, -1, false)
TiffFile{O}(io::IO) where O <: Unsigned    = TiffFile{O}(getstream(format"TIFF", io))
TiffFile{O}() where O <: Unsigned          = TiffFile{O}(IOBuffer())

function Base.read(io::Stream, ::Type{TiffFile})
    seekstart(io)
    filepath = String(extract_filename(io))::String
    bs = need_bswap(io)
    offset_size = offsetsize(io)
    first_offset_raw = read(io, offset_size)
    first_offset = Int(bs ? bswap(first_offset_raw) : first_offset_raw)
    TiffFile{offset_size, typeof(io)}(nothing, filepath, io, first_offset, bs)
end

Base.read(io::IOStream, t::Type{TiffFile}) = read(getstream(format"TIFF", io, extract_filename(io)), t)

"""
    sizeof(file)

Number of bytes that `file`'s header will use on disk
"""
Base.sizeof(file::TiffFile{UInt32}) = 8
Base.sizeof(file::TiffFile{UInt64}) = 16

function Base.write(file::TiffFile{O}) where O
    seekstart(file.io)

    if ENDIAN_BOM == 0x04030201 #little endian
        write(file.io, "II")
    else
        write(file.io, "MM")
    end

    ifd_pos = 4 # position where the offset info is
    if O == UInt32
        write(file.io, UInt16(42)) # regular tiff
        write(file.io, UInt32(8)) # first offset is right after header
    elseif O == UInt64
        write(file.io, UInt16(43)) # big tiff
        write(file.io, UInt16(8)) # byte size of offsets
        write(file.io, UInt16(0)) # constant
        ifd_pos = position(file.io)
        write(file.io, UInt64(16)) # first offset is right after header
    else
        error("Unknown offset size")
    end
    ifd_pos
end


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
    _read!(stream(file.io), arr)
    if file.need_bswap
        arr .= bswap.(arr)
    end
end

function Base.read!(file::TiffFile, arr::SubArray{T,N,<:BitArray}) where {T, N}
    error("Strided bilevel TIFFs are not yet supported. Please open an issue against TiffImages.jl.")
end

function Base.read!(file::TiffFile, arr::BitArray)
    Bc = arr.chunks
    n = length(arr)
    nc = length(read!(file.io, Bc))
    if length(Bc) > 0 && Bc[end] & Base._msk_end(n) ≠ Bc[end]
        Bc[end] &= Base._msk_end(n) # ensure that the BitArray is not broken
    end
    for i in 1:nc
       Bc[i] = reversebits(Bc[i])
    end
    arr
end

Base.write(file::TiffFile, t) = write(file.io.io, t)::Int
Base.write(file::TiffFile, arr::AbstractVector{Any}) = write(file.io.io, Array{UInt8}(arr))::Int

Base.seek(file::TiffFile, n::Integer) = seek(file.io, n)

Base.bswap(x::Rational{T}) where {T} = Rational(bswap(x.num), bswap(x.den))

Base.IteratorSize(::TiffFile) = Base.SizeUnknown()
Base.eltype(::TiffFile{O}) where {O} = IFD{O}
