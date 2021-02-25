@testset "Unspecified type" begin
    tf = TiffImages.TiffFile{UInt32}()

    write(tf, UInt16(TiffImages.IMAGEWIDTH))
    write(tf, 0x0007)
    write(tf, UInt32(2))
    write(tf, UInt16[8, 1])

    seekstart(tf.io)
    @test read(tf, TiffImages.Tag) == TiffImages.Tag(TiffImages.IMAGEWIDTH, Any[8, 0, 1, 0])
end

@testset "Data array only part of data field" begin
    tf = TiffImages.TiffFile{UInt64}()

    write(tf, UInt16(TiffImages.BITSPERSAMPLE))
    write(tf, 0x0003)
    write(tf, UInt64(2))
    write(tf, UInt16[8, 8])
    write(tf, UInt32(0))

    seekstart(tf.io)
    @test length(read(tf, TiffImages.Tag).data) == 2 # not 4
end

@testset "Rational, full space" begin
    tf = TiffImages.TiffFile{UInt64}()
    write(tf, UInt16(TiffImages.XRESOLUTION))
    write(tf, 0x0005)
    write(tf, UInt64(1))
    ratio = Rational{UInt32}(1, 20)
    write(tf, ratio)

    seekstart(tf.io)
    @test read(tf, TiffImages.Tag).data == ratio
end