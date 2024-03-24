@testset "Interpretations" begin
    ifd = TiffImages.IFD(UInt32)
    ifd[TiffImages.PHOTOMETRIC] = TiffImages.PHOTOMETRIC_MINISBLACK
    ifd[TiffImages.SAMPLESPERPIXEL] = 1

    @test TiffImages.interpretation(ifd) == (Gray, false)

    ifd[TiffImages.SAMPLESPERPIXEL] = 2
    @test TiffImages.interpretation(ifd) == (Gray, true)

    # handle case where SamplesPerPixel is missing, issue #56
    delete!(ifd, TiffImages.SAMPLESPERPIXEL)
    @test TiffImages.interpretation(ifd) == (Gray, false)

    ifd[TiffImages.SAMPLESPERPIXEL] = 2
    ifd[TiffImages.EXTRASAMPLES] = TiffImages.EXTRASAMPLE_ASSOCALPHA

    @test TiffImages.interpretation(ifd) == (GrayA, false)

    ifd[TiffImages.EXTRASAMPLES] = TiffImages.EXTRASAMPLE_UNSPECIFIED

    @test TiffImages.interpretation(ifd) == (Gray, true)

    ifd[TiffImages.SAMPLESPERPIXEL] = 3

    @test TiffImages.interpretation(ifd) == (Gray, true)

    ifd[TiffImages.PHOTOMETRIC] = TiffImages.PHOTOMETRIC_RGB

    @test TiffImages.interpretation(ifd) == (RGB, false)

    ifd[TiffImages.SAMPLESPERPIXEL] = 4

    @test TiffImages.interpretation(ifd) == (RGBX, false)

    ifd[TiffImages.EXTRASAMPLES] = TiffImages.EXTRASAMPLE_ASSOCALPHA

    @test TiffImages.interpretation(ifd) == (RGBA, false)
end

@testset "Sample Types" begin
    @test TiffImages.bitspersample(RGB{Float32}) == 32
    @test TiffImages.bitspersample(RGB{N1f7}) == 7
    @test TiffImages.bitspersample(RGB{Q4f11}) == 12
end