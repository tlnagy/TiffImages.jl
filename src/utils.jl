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



const _mask1_uint128 = (UInt128(0x5555555555555555) << 64) | UInt128(0x5555555555555555)
const _mask2_uint128 = (UInt128(0x3333333333333333) << 64) | UInt128(0x3333333333333333)
const _mask4_uint128 = (UInt128(0x0f0f0f0f0f0f0f0f) << 64) | UInt128(0x0f0f0f0f0f0f0f0f)

"""
    reversebits(x)

Reverse the bit order in each byte of `x`. Julia assumes the first bit of each
byte is packed as a 0x01, while in TIFFs it's actually packed as 0x80. This
function flips the bit packing order. 

!!! note
    This function does not flip the byte packing order, a la `bswap`.

This function should be applied to a BitArray after it is read in via
[`reversebits!`](@ref). 

Code adapted from https://github.com/JuliaLang/julia/pull/34791

```jldoctest
julia> TIFF.reversebits(0x0101) == 0x8080
true
```
"""
function reversebits(x::Base.BitInteger)
    z = unsigned(x)
    mask1 = _mask1_uint128 % typeof(z)
    mask2 = _mask2_uint128 % typeof(z)
    mask4 = _mask4_uint128 % typeof(z)
    z = ((z & mask1) << 1) | ((z >> 1) & mask1)
    z = ((z & mask2) << 2) | ((z >> 2) & mask2)
    z = ((z & mask4) << 4) | ((z >> 4) & mask4)
    return z
end

"""
    reversebits!(x)

Flips the bits in every byte backing `x`. Does not change byte order.
"""
function reversebits!(x::BitArray)
    n = length(x.chunks)
    for i in 1:n
        x.chunks[i] = reversebits(x.chunks[i])
    end
end

# using rephorm's table from
# https://github.com/rephorm/TIFF.jl/blob/master/tiff.jl#L30
const tiff_to_julian = Dict(
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

const julian_to_tiff = Dict(
    UInt8               => 0x0001,   # CHAR
    String              => 0x0002,   # ASCII
    UInt16              => 0x0003,   # SHORT
    UInt32              => 0x0004,   # LONG
    Rational{UInt32}    => 0x0005,   # RATIONAL
    Int8                => 0x0006,   # SBYTE
    Any                 => 0x0007,   # UNDEFINED
    Int16               => 0x0008,   # SSHORT
    Int32               => 0x0009,   # SLONG
    Rational{Int32}     => 0x000a,   # SRATIONAL
    Float32             => 0x000b,   # FLOAT
    Float64             => 0x000c,   # DOUBLE
    UInt64              => 0x0010,   # LONG8
    Int64               => 0x0011,   # SLONG8
)

# sampleformat, bitspersample => Julian type
const rawtype_mapping = Dict(
    (SAMPLEFORMAT_UINT, 1) => Bool,
    (SAMPLEFORMAT_UINT, 8) => UInt8,
    (SAMPLEFORMAT_UINT, 16) => UInt16,
    (SAMPLEFORMAT_UINT, 32) => UInt32,
    (SAMPLEFORMAT_UINT, 64) => UInt64,
    (SAMPLEFORMAT_INT, 8) => Int8,
    (SAMPLEFORMAT_INT, 16) => Int16,
    (SAMPLEFORMAT_INT, 32) => Int32,
    (SAMPLEFORMAT_INT, 64) => Int64,
    (SAMPLEFORMAT_IEEEFP, 16) => Float16,
    (SAMPLEFORMAT_IEEEFP, 32) => Float32,
    (SAMPLEFORMAT_IEEEFP, 64) => Float64,
)
