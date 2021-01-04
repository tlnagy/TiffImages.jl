@testset "exact fit tags" begin
    tf = TIFF.TiffFile(UInt32)
    t1 = TIFF.Tag{UInt32}(UInt16(TIFF.IMAGEWIDTH), UInt32, 1, UInt8[0,2,0,0], true)
    @test write(tf, t1) # should fit so true

    seekstart(tf.io)
    t2 = read(tf, TIFF.Tag{UInt32})
    @test t1 == t2
end

@testset "small tags" begin
    tf = TIFF.TiffFile(UInt32)
    t1 = TIFF.Tag{UInt32}(UInt16(TIFF.COMPRESSION), UInt16, 1, [0x01, 0x00], true)
    @test write(tf, t1) # should fit but needs padding
    @test position(tf.io) == 12 # should be full length

    seekstart(tf.io)
    t2 = read(tf, TIFF.Tag{UInt32})
    @test t2.data == [0x0001, 0x0000]
end

@testset "large tags" begin
    tf = TIFF.TiffFile(UInt32)
    offsets = UInt32[8, 129848, 259688, 389528]
    t1 = TIFF.Tag{UInt32}(UInt16(TIFF.STRIPOFFSETS), UInt32, 4, Array(reinterpret(UInt8, offsets)), true)
    
    @test !write(tf, t1) # should fail to write into tf since it's too large 
    @test position(tf.io) == 12
    
    data = Array{UInt8}(undef, 12)
    seekstart(tf.io)
    read!(tf.io, data)

    @test all(data .== 0x00)

    seekstart(tf.io)
    @test write(tf, t1, 12)

    seekstart(tf.io)
    t2 = read(tf, TIFF.Tag{UInt32})

    # make sure the data field contains our single offset from above
    @test Int.(reinterpret(UInt32, getfield(t2, :data))) == [12]
end