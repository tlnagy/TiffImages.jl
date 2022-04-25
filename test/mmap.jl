@testset "Extant File mmap" begin
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

@testset "De novo construction" begin
    rm("test.tif", force = true)
    img = memmap(Gray{N0f8}, "test.tif")

    # a newly initialized file should have every dimension equal to zero and
    # error if accessed
    @test size(img) == (0, 0, 0)
    @test_throws ErrorException img[1, 1, 1]

    push!(img, rand(Gray{N0f8}, 100, 100))
    @test size(img) == (100, 100, 1)
    @test TiffImages.offset(img) == UInt32

    @test_throws AssertionError push!(img, rand(Gray{N0f8}, 99, 99)) # wrong size
    
    @testset "BigTIFF" begin
        rm("test.btif", force = true)
        img = memmap(Gray{N0f8}, "test.btif"; bigtiff = true)

        push!(img, rand(Gray{N0f8}, 100, 100))
        @test size(img) == (100, 100, 1)
        @test TiffImages.offset(img) == UInt64
    end

    img.readonly = true
    @test_throws ErrorException push!(img, rand(Gray{N0f8}, 100, 100))
end