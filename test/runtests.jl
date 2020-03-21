using ColorTypes
using Documenter
using FixedPointNumbers
using Test
using TIFF
using TestImages

DocMeta.setdocmeta!(TIFF, :DocTestSetup, :(using TIFF); recursive=true)
doctest(TIFF)

@testset "Gray with ExtraSample" begin
    filepath = testimage("house.tif", download_only=true)
    img = TIFF.load(filepath)
    @test size(img) == (512, 512)
    @test eltype(img) == Gray{N0f8}
    @test img[50,50] == Gray{N0f8}(0.804) # value from ImageMagick.jl
    img[50:300, 50:150] .= 0.0
    @test img[50, 50] == Gray{N0f8}(0.0)
0
end

@testset "MRI stack" begin
    filepath = testimage("mri-stack.tif", download_only=true)
    img = TIFF.load(filepath)
    @test size(img) == (226, 186, 27)
    @test eltype(img) == Gray{N0f8}
    @test img[50,50,1] == Gray{N0f8}(0.353) # value from ImageMagick.jl
end

@testset "RGB image" begin
    filepath = testimage("lake_color.tif", download_only=true)
    img = TIFF.load(filepath)
    @test size(img) == (512, 512)
    @test eltype(img) == RGB{N0f8}
    @test img[50,50] == RGB{N0f8}(0.392,0.188,0.196) # value from ImageMagick.jl
end

@testset "Packbits image" begin
    filepath = download("http://people.math.sc.edu/Burkardt/data/tif/m83.tif")
    img = TIFF.load(filepath)
    @test size(img) == (378, 400)
    @test eltype(img) == RGB{N0f16}
end