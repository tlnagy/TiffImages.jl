@testset "tags" begin
    @testset "exact fit tags" begin
        tf = TiffImages.TiffFile(UInt32)
        t1 = TiffImages.Tag(UInt16(TiffImages.IMAGEWIDTH), 0x00000200)
        @test write(tf, t1) # should fit so true

        seekstart(tf.io)
        t2 = read(tf, TiffImages.Tag)
        @test t1 == t2
    end

    @testset "small tags" begin
        tf = TiffImages.TiffFile(UInt32)
        t1 = TiffImages.Tag(UInt16(TiffImages.COMPRESSION), 0x0001)
        @test write(tf, t1) # should fit but needs padding
        @test position(tf.io) == 12 # should be full length

        seekstart(tf.io)
        t2 = read(tf, TiffImages.Tag)
        @test t2.data == 0x0001
    end

    @testset "large tags" begin
        tf = TiffImages.TiffFile(UInt32)
        offsets = UInt32[8, 129848, 259688, 389528]
        t1 = TiffImages.Tag(UInt16(TiffImages.STRIPOFFSETS), offsets)

        @test !write(tf, t1) # should fail to write into tf since it's too large
        @test position(tf.io) == 12

        data = Array{UInt8}(undef, 12)
        seekstart(tf.io)
        read!(tf.io, data)

        @test all(data .== 0x00)

        seekstart(tf.io)
        @test write(tf, t1, 12)

        seekstart(tf.io)
        t2 = read(tf, TiffImages.Tag)

        # make sure the data field contains our single offset from above
        @test typeof(t2.data) <: TiffImages.RemoteData
        @test t2.data.position == 12
    end

    @testset "String length equal to offset size" begin
        tf = TiffImages.TiffFile(UInt32)
        t1 = TiffImages.Tag(TiffImages.SOFTWARE, "test")

        # should fail because it's too large to fit
        @test !write(tf, t1)
        @test position(tf.io) == 12

        t3 = TiffImages.Tag(TiffImages.SOFTWARE, "tes\0")
        seekstart(tf.io)
        @test write(tf, t3)
        @test position(tf.io) == 12

        seekstart(tf.io)
        t4 = read(tf, TiffImages.Tag)

        # Since this is a NUL-terminated string of length 4 it should fit
        @test getfield(t4, :data) == "tes\0"
        @test t4.data == "tes"
    end
end

@testset "ifds" begin
    tf = TiffImages.TiffFile(UInt32)
    ifd = TiffImages.IFD(UInt32)
    ifd[TiffImages.IMAGEDESCRIPTION] = "Testing IFD read/write"
    ifd[TiffImages.IMAGEWIDTH] = UInt32(512)
    ifd[TiffImages.IMAGELENGTH] = UInt32(512)
    ifd[TiffImages.XRESOLUTION] = Rational{UInt32}(72, 1)
    ifd[TiffImages.COMPRESSION] = TiffImages.COMPRESSION_NONE
    ifd[TiffImages.SAMPLESPERPIXEL] = 1
    ifd[TiffImages.PHOTOMETRIC] = TiffImages.PHOTOMETRIC_MINISBLACK
    ifd[TiffImages.STRIPBYTECOUNTS] = UInt32[512*512]
    ifd[TiffImages.BITSPERSAMPLE] = 8
    ifd[TiffImages.ICCPROFILE] = Any[0x00, 0x00, 0x0b, 0xe8, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x6d]

    write(tf, ifd)

    seekstart(tf.io)
    read_ifd, next_ifd = read(tf, TiffImages.IFD)
    TiffImages.load!(tf, read_ifd)

    @test all(ifd .== read_ifd)

    expected = TiffImages.IFDLayout(1, 512, 512, 262144,
                                    UInt8, UInt8, FixedPointNumbers.Normed{UInt8,8},
                                    TiffImages.COMPRESSION_NONE,
                                    TiffImages.PHOTOMETRIC_MINISBLACK)
    @test TiffImages.output(ifd) == expected

    delete!(ifd, TiffImages.COMPRESSION)

    @test TiffImages.output(ifd) == expected
end

@testset "Simple 2D image" begin
    filepath = get_example("house.tif")
    img = TiffImages.load(filepath)

    img2 = TiffImages.DenseTaggedImage(Gray{Float64}.(img.data));
    path, io = mktemp()
    write(io, img2)
    img3 = TiffImages.load(path)
    @test eltype(img3) == Gray{Float64}
end

@testset "3D image" begin
    filepath = get_example("mri.tif")
    img = TiffImages.load(filepath)

    img2 = TiffImages.DenseTaggedImage(RGB{Float64}.(img.data));
    path, io = mktemp()
    write(io, img2)
    img3 = TiffImages.load(path)
    @test eltype(img3) == RGB{Float64}
end

@testset "BigTIFF saving" begin
    filepath = get_example("house.tif")
    img = TiffImages.load(filepath)

    ifd = TiffImages._constructifd(img.data, UInt64);
    img2 = TiffImages.DenseTaggedImage(img.data, ifd)
    path, io = mktemp()
    write(io, img2)
    img3 = TiffImages.load(path)
    @test eltype(img3) == GrayA{N0f8}
end