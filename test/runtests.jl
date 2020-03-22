using ColorTypes
using Documenter
using FixedPointNumbers
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