@testset "tags" begin
    @testset "exact fit tags" begin
        tf = TiffImages.TiffFile(UInt32)
        t1 = TiffImages.Tag{UInt32}(UInt16(TiffImages.IMAGEWIDTH), UInt32, 1, UInt8[0,2,0,0], true)
        @test write(tf, t1) # should fit so true

        seekstart(tf.io)
        t2 = read(tf, TiffImages.Tag{UInt32})
        @test t1 == t2
    end

    @testset "small tags" begin
        tf = TiffImages.TiffFile(UInt32)
        t1 = TiffImages.Tag{UInt32}(UInt16(TiffImages.COMPRESSION), UInt16, 1, [0x01, 0x00], true)
        @test write(tf, t1) # should fit but needs padding
        @test position(tf.io) == 12 # should be full length

        seekstart(tf.io)
        t2 = read(tf, TiffImages.Tag{UInt32})
        @test t2.data == [0x0001, 0x0000]
    end

    @testset "large tags" begin
        tf = TiffImages.TiffFile(UInt32)
        offsets = UInt32[8, 129848, 259688, 389528]
        t1 = TiffImages.Tag{UInt32}(UInt16(TiffImages.STRIPOFFSETS), UInt32, 4, Array(reinterpret(UInt8, offsets)), true)

        @test !write(tf, t1) # should fail to write into tf since it's too large
        @test position(tf.io) == 12

        data = Array{UInt8}(undef, 12)
        seekstart(tf.io)
        read!(tf.io, data)

        @test all(data .== 0x00)

        seekstart(tf.io)
        @test write(tf, t1, 12)

        seekstart(tf.io)
        t2 = read(tf, TiffImages.Tag{UInt32})

        # make sure the data field contains our single offset from above
        @test Int.(reinterpret(UInt32, getfield(t2, :data))) == [12]
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

    write(tf, ifd)

    seekstart(tf.io)
    read_ifd, next_ifd = read(tf, TiffImages.IFD)
    TiffImages.load!(tf, read_ifd)

    @test all(ifd .== read_ifd)
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