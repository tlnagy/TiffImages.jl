using ColorTypes
using ColorVectorSpace
using Documenter
using FixedPointNumbers
using Statistics
using Test
using TIFF

DocMeta.setdocmeta!(TIFF, :DocTestSetup, :(using TIFF); recursive=true)
doctest(TIFF)

get_example(name) = download("https://github.com/tlnagy/exampletiffs/blob/master/$name?raw=true")

@testset "Gray with ExtraSample" begin
    filepath = get_example("house.tif")
    img = TIFF.load(filepath)
    @test size(img) == (512, 512)
    @test eltype(img) == Gray{N0f8}
    @test img[50,50] == Gray{N0f8}(0.804) # value from ImageMagick.jl
    img[50:300, 50:150] .= 0.0
    @test img[50, 50] == Gray{N0f8}(0.0)
0
end

@testset "MRI stack" begin
    filepath = get_example("mri.tif")
    img = TIFF.load(filepath)
    @test size(img) == (128, 128, 27)
    @test eltype(img) == RGB{N0f16}

    @testset "Multiple planes" begin
        # test slice based access
        @test Gray(mean(img[:, :, 2])) == Gray{Float32}(0.25676906f0)

        # make sure IFDs are included if whole slice is grabbed
        @test length(img[:, :, 2].ifds) == 1
        @test length(img[:, :, 2:5].ifds) == 4

        # make sure that subslicing in XY drops IFD info
        @test typeof(img[:, 50:60, 27]) == Array{RGB{Normed{UInt16,16}},2}
    end
end

@testset "Floating point RGB image" begin
    filepath = get_example("spring.tif")
    img = TIFF.load(filepath)
    @test size(img) == (619, 858)
    @test eltype(img) == RGB{Float16}
end

@testset "Packbits image" begin
    filepath = get_example("coffee.tif")
    img = TIFF.load(filepath)
    @test size(img) == (378, 504)
    @test eltype(img) == Gray{N0f8}
end

@testset "Bilevel image" begin
    filepath = get_example("capitol.tif")
    img = TIFF.load(filepath)
    @test size(img) == (378, 504)
    @test eltype(img) == Gray{Bool}
end