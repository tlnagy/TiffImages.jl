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

Base.seek(file::TiffFile, n::Integer) = seek(file.io, n)

Base.bswap(x::Rational{T}) where {T} = Rational(bswap(x.num), bswap(x.den))

Base.IteratorSize(::TiffFile) = Base.SizeUnknown()

"""
    do_bswap(file, values) -> Array

If the endianness of file is different than that of the current machine, swap
the byte order.
"""
function do_bswap(file::TiffFile, values::AbstractArray)
    if file.need_bswap
        values .= bswap.(values)
    end
    values
end

do_bswap(file::TiffFile, value) = file.need_bswap ? bswap(value) : value