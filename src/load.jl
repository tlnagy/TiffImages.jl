function load(filepath)
    tf = TiffFile(open(filepath))

    nrows = 1
    ncols = 1
    nplanes = 1
    bitsperpixel = 1

    isdense = true
    ifds = IFD{offset(tf)}[]

    for ifd in tf
        push!(ifds, ifd)

        nrows = Int(get(tf, ifd[IMAGEWIDTH])[1])
        ncols = Int(get(tf, ifd[IMAGELENGTH])[1])

        bitsperpixel = Int(get(tf, getindex(ifd, BITSPERSAMPLE, 1))[1])

        nplanes += 1
    end

    rawtype = UInt16
    mappedtype = Normed{rawtype, bitsperpixel}

    data = Array{rawtype}(undef, nrows, ncols, nplanes)
    for (idx, ifd) in enumerate(ifds)
        read!(view(data, :, :, idx), tf, ifd)
    end

    close(tf.io)
    DenseTaggedImage(reinterpret(Gray{mappedtype}, data), ifds)
end