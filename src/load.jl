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

    data = Array{layout.rawtype}(undef, layout.nsamples, layout.ncols, layout.nrows, nplanes)
    for (idx, ifd) in enumerate(ifds)
        read!(PermutedDimsArray(view(data, :, :, :, idx), [1, 3, 2]), tf, ifd)
    end

    close(tf.io)
    colortype = nothing
    if layout.interpretation == PHOTOMETRIC_MINISBLACK
        colortype = Gray{layout.mappedtype}
    elseif layout.interpretation == PHOTOMETRIC_RGB
        colortype = RGB{layout.mappedtype}
    else
        error("Given TIFF requests $(layout.interpretation) interpretation, but that's not yet supported")
    end
    DenseTaggedImage(dropdims(reinterpret(colortype, data), dims=1), ifds)
end