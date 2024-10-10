using ColorTypes
using ColorVectorSpace
using FixedPointNumbers
using Downloads
using Test
using TiffImages

if !@isdefined(get_example)
    _wrap(name) = "https://github.com/tlnagy/exampletiffs/blob/master/$name?raw=true"
    get_example(x) = Downloads.download(_wrap(x))
end

@testset "Adobe Deflate image using CodecZlib" begin
    @eval using CodecZlib
    filepath = get_example("underwater_bmx.tif")
    img = TiffImages.load(filepath)
    @test Base.get_extension(TiffImages, :CodecZlibExt) != nothing
    @test size(img) == (773, 1076)
    @test eltype(img) == RGB{N0f8}

    # Efficient convert method
    img_cvt = convert(Array{eltype(img), ndims(img)}, img)
    @test img_cvt === img.data

    # Dirty patch the TIFF_COMPRESSION tag from
    # COMPRESSION_ADOBE_DEFLATE (8) to COMPRESSION_DEFLATE (32946).
    # Those are in fact exactly the same so nothing else needs to be
    # adjusted.
    data = read(filepath)
    @assert data[1063947:1063948] == [0x08, 0x00]
    data[1063947:1063948] .= reinterpret(UInt8, [UInt16(32946)])
    _, io = mktemp()
    write(io, data)
    seekstart(io)
    img = TiffImages.load(io)
    @test size(img) == (773, 1076)
    @test eltype(img) == RGB{N0f8}
end

