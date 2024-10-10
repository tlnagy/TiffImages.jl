module CodecZlibExt
    import TiffImages
    using CodecZlib: ZlibDecompressorStream

    function __init__()
        # Use faster binary Zlib decompression rather than Inflate.jl when available
        TiffImages.set_zlib_decompression_stream!(ZlibDecompressorStream)
    end
end
