function load(filepath)
    tf = TiffFile(open(filepath))

    isdense = true
    ifds = IFD{offset(tf)}[]

    layout = nothing
    nplanes = 0

    for ifd in tf
        push!(ifds, ifd)

        new_layout = output(tf, ifd)

        # if we detect variance in the format of the IFD data then we can't
        # represent the image as a dense array
        if layout != nothing && layout != new_layout
            isdense = false
            @info "Not dense"
        end
        layout = new_layout

        nplanes += 1
    end
    if layout.rawtype == Bool
        data = BitArray(undef, layout.nbytes*8, nplanes)
    else
        data = Array{layout.rawtype}(undef, layout.nbytes÷sizeof(layout.rawtype), nplanes)
    end
    @showprogress for (idx, ifd) in enumerate(ifds)
        read!(view(data, :, idx), tf, ifd)
    end
    trans = reshape(data, :, layout.nrows, nplanes) 
    if layout.rawtype == Bool
        trans = view(trans, 1:layout.ncols, 1:layout.nrows, 1:nplanes)
    end
    if layout.nsamples > 1
        trans = PermutedDimsArray(reshape(trans, layout.nsamples, layout.ncols, layout.nrows, nplanes), [1, 3, 2, 4])
    else
        trans = PermutedDimsArray(trans, [2, 1, 3])
    end

    colortype = nothing
    if layout.interpretation == PHOTOMETRIC_PALETTE
        ifd = first(ifds)
        maxdepth = 2^(get(tf, ifd[BITSPERSAMPLE])[1])-1
        colors = get(tf, ifd[COLORMAP])
        color_map = vec(reinterpret(RGB{N0f16}, reshape(colors, :, 3)'))
        trans = IndirectArray(trans, OffsetArray(color_map, 0:maxdepth))
    else
        if layout.interpretation == PHOTOMETRIC_MINISBLACK
            colortype = Gray{layout.mappedtype}
        elseif layout.interpretation == PHOTOMETRIC_RGB
            colortype = RGB{layout.mappedtype}
        else
            error("Given TIFF requests $(layout.interpretation) interpretation, but that's not yet supported")
        end
        trans = reinterpret(colortype, trans)
    end
    close(tf.io)
    todrop = tuple(findall(size(trans) .== 1)...)
    DenseTaggedImage(dropdims(trans, dims=todrop), ifds)
end