"""
    extract_filename(io) -> String

Extract the name of the file backing a stream
"""
extract_filename(io::IOStream) = split(io.name, " ")[2][1:end-1]
extract_filename(io::Stream) = io.filename

"""
    check_bswap(io::Stream)

Check endianness of TIFF file to see if we need to swap bytes
"""
function need_bswap(io::Stream)
    seekstart(io)
    endianness = String(read(io, 2))
    # check if we need to swap byte order
    bswap = endianness != (ENDIAN_BOM == 0x04030201 ? "II" : "MM")
    return bswap
end

function offsetsize(io::Stream)
    seek(io, 2)
    tiff_version = Array{UInt8}(undef, 2)
    read!(io, tiff_version)
    if tiff_version == [0x2a, 0x00] || tiff_version == [0x00, 0x2a]
        return UInt32
    elseif tiff_version == [0x2b, 0x00] || tiff_version == [0x00, 0x2b]
        offset_bytesize = read(io, UInt16)
        constant = read(io, UInt16)
        return UInt64
    else
        error("Unknown TIFF version")
    end
end


# using rephorm's table from
# https://github.com/rephorm/TIFF.jl/blob/master/tiff.jl#L30
const type_mapping = Dict(
  0x0001 => UInt8,            # CHAR
  0x0002 => String,           # ASCII
  0x0003 => UInt16,           # SHORT
  0x0004 => UInt32,           # LONG
  0x0005 => Rational{UInt32}, # RATIONAL
  0x0006 => Int8,             # SBYTE
  0x0007 => Any,              # UNDEFINED
  0x0008 => Int16,            # SSHORT
  0x0009 => Int32,            # SLONG
  0x000a => Rational{Int32},  # SRATIONAL
  0x000b => Float32,          # FLOAT
  0x000c => Float64,          # DOUBLE
  0x000d => UInt32,           # IFD
  0x0010 => UInt64,           # LONG8
  0x0011 => Int64,            # SLONG8
  0x0012 => UInt64,           # IFD8
)

# sampleformat, bitspersample => Julian type
const rawtype_mapping = Dict(
    (SAMPLEFORMAT_UINT, 1) => Bool,
    (SAMPLEFORMAT_UINT, 8) => UInt8,
    (SAMPLEFORMAT_UINT, 16) => UInt16,
    (SAMPLEFORMAT_UINT, 32) => UInt32,
    (SAMPLEFORMAT_UINT, 64) => UInt64,
    (SAMPLEFORMAT_IEEEFP, 16) => Float16,
    (SAMPLEFORMAT_IEEEFP, 32) => Float32,
    (SAMPLEFORMAT_IEEEFP, 64) => Float64,
)