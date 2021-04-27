using ColorTypes
using ColorVectorSpace
using Documenter
using FixedPointNumbers
using OffsetArrays
import AxisArrays: AxisArray # No, we don't want to export `AxisArrays.axes`
using Statistics
using Test
using TiffImages

if VERSION >= v"1.4"
    DocMeta.setdocmeta!(TiffImages, :DocTestSetup, :(using TiffImages); recursive=true)
    doctest(TiffImages)
end

_wrap(name) = "https://github.com/tlnagy/exampletiffs/blob/master/$name?raw=true"

if VERSION >= v"1.6.0"
    using Downloads
    get_example(x) = Downloads.download(_wrap(x))
else
    get_example(x) = download(_wrap(x))
end

@testset "Tag loading" begin
    include("tags.jl")
end

@testset "Gray with ExtraSample" begin
    filepath = get_example("house.tif")
    img = TiffImages.load(filepath)
    @test size(img) == (512, 512)
    @test eltype(img) == GrayA{N0f8}
    @test img[50,50] == GrayA{N0f8}(0.804, 1.0) # value from ImageMagick.jl
    img[50:300, 50:150] .= 0.0
    @test img[50, 50] == GrayA{N0f8}(0.0, 1.0)

    # Efficient convert method
    img_cvt = convert(Array{eltype(img), ndims(img)}, img)
    @test img_cvt === img.data
end

@testset "MRI stack" begin
    filepath = get_example("mri.tif")
    img = TiffImages.load(filepath)
    @test size(img) == (128, 128, 27)
    @test eltype(img) == RGB{N0f16}

    # TODO: inefficient convert method
    img_cvt = convert(Array{eltype(img), ndims(img)}, img)
    @test img_cvt == img.data
    @test img_cvt !== img.data

    @testset "Multiple planes" begin
        # test slice based access
        @test red(img[92, 21, 2]) == 0.74118N0f16

        # make sure IFDs are included if whole slice is grabbed
        @test length(img[:, :, 2].ifds) == 1
        @test length(img[:, :, 2:5].ifds) == 4

        # make sure that subslicing in XY drops IFD info
        @test typeof(img[:, 50:60, 27]) == Array{RGB{Normed{UInt16,16}},2}
    end
end

@testset "Floating point RGB image" begin
    filepath = get_example("spring.tif")
    img = TiffImages.load(filepath)
    @test size(img) == (619, 858)
    @test eltype(img) == RGB{Float16}
    
    # Efficient convert method
    img_cvt = convert(Array{eltype(img), ndims(img)}, img)
    @test img_cvt === img.data
end

@testset "Packbits image" begin
    filepath = get_example("coffee.tif")
    img = TiffImages.load(filepath)
    @test size(img) == (378, 504)
    @test eltype(img) == Gray{N0f8}
    
    # Efficient convert method
    img_cvt = convert(Array{eltype(img), ndims(img)}, img)
    @test img_cvt === img.data
end

@testset "Bilevel image" begin
    filepath = get_example("capitol.tif")
    img = TiffImages.load(filepath)
    @test size(img) == (378, 504)
    @test eltype(img) == Gray{Bool}
    
    # Efficient convert method
    img_cvt = convert(Array{eltype(img), ndims(img)}, img)
    @test img_cvt === img.data
end

@testset "Striped bilevel image" begin
    filepath = get_example("capitol2.tif")
    img = TiffImages.load(filepath)
    @test size(img) == (378, 504)
    @test eltype(img) == Gray{Bool}

    # Efficient convert method
    img_cvt = convert(Array{eltype(img), ndims(img)}, img)
    @test img_cvt === img.data
end

@testset "Signed integer type" begin
    filepath = get_example("4D-series.ome.tif")
    img = TiffImages.load(filepath)

    @test size(img) == (167, 439, 35)
    expected_rng = reinterpret.(Q0f7, Int8.((-1, 96)))
    @test extrema(img[:, :, 1]) == expected_rng

    # Efficient convert method
    img_cvt = convert(Array{eltype(img), ndims(img)}, img)
    @test img_cvt === img.data
end

@testset "Discontiguous striped image, Issue #38" begin
    filepath = get_example("julia.tif")
    img = TiffImages.load(filepath)

    @test size(img) == (300, 500)
    # if discontiguous striping is broken then the garbage padding data will
    # leak into the actual image
    @test all(img[3, 1:50] .== RGB{N0f8}(1, 1, 1))

    # Efficient convert method
    img_cvt = convert(Array{eltype(img), ndims(img)}, img)
    @test img_cvt === img.data
end

@testset "Issue #12" begin
    @testset "Big endian striped file" begin
        filepath = get_example("flagler.tif")
        img = TiffImages.load(filepath)

        # verify that strip offsets are correctly bswapped for endianness
        img_stripoffsets = Int.(img.ifds[1][TiffImages.STRIPOFFSETS].data)
        @test img_stripoffsets == [8, 129848, 259688, 389528]

        # Efficient convert method
        img_cvt = convert(Array{eltype(img), ndims(img)}, img)
        @test img_cvt === img.data
    end

    @testset "Little endian striped file" begin
        filepath = get_example("house.tif")
        img = TiffImages.load(filepath)

        # verify that strip offsets are correctly bswapped for endianness
        img_stripoffsets = Int.(img.ifds[1][TiffImages.STRIPOFFSETS].data)
        @test issorted(img_stripoffsets)

        # Efficient convert method
        img_cvt = convert(Array{eltype(img), ndims(img)}, img)
        @test img_cvt === img.data
    end
end

@testset "Mmap" begin
    filepath = get_example("julia.tif")
    img = TiffImages.load(filepath, mmap=true)
    @test size(img) == (300, 500, 1)
    @test all(img[3, 1:50] .== RGB{N0f8}(1, 1, 1))
    # force close the stream behind the file to see if it's properly reopened 
    close(img.data.file.io)
    @test all(img[3, 1:50] .== RGB{N0f8}(1, 1, 1))

    # TODO: inefficient convert method
    img_cvt = convert(Array{eltype(img), ndims(img)}, img)
    @test img_cvt == img.data
    @test img_cvt !== img.data
end

@testset "Writing" begin
    include("writer.jl")
end

@testset "Interpreting IFD layouts" begin
    include("layouts.jl")
end
