@testset "Interpretations" begin
    ifd = TIFF.IFD(UInt32)
    ifd[TIFF.PHOTOMETRIC] = TIFF.PHOTOMETRIC_MINISBLACK
    ifd[TIFF.SAMPLESPERPIXEL] = 1

    @test TIFF.interpretation(ifd) == (Gray, false)

    ifd[TIFF.SAMPLESPERPIXEL] = 2

    @test TIFF.interpretation(ifd) == (Gray, true)

    ifd[TIFF.EXTRASAMPLES] = TIFF.EXTRASAMPLE_ASSOCALPHA

    @test TIFF.interpretation(ifd) == (GrayA, false)

    ifd[TIFF.EXTRASAMPLES] = TIFF.EXTRASAMPLE_UNSPECIFIED

    @test TIFF.interpretation(ifd) == (Gray, true)

    ifd[TIFF.SAMPLESPERPIXEL] = 3

    @test TIFF.interpretation(ifd) == (Gray, true)

    ifd[TIFF.PHOTOMETRIC] = TIFF.PHOTOMETRIC_RGB

    @test TIFF.interpretation(ifd) == (RGB, false)

    ifd[TIFF.SAMPLESPERPIXEL] = 4

    @test TIFF.interpretation(ifd) == (RGBX, false)

    ifd[TIFF.EXTRASAMPLES] = TIFF.EXTRASAMPLE_ASSOCALPHA 

    @test TIFF.interpretation(ifd) == (RGBA, false)
end