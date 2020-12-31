function load(filepath::String; verbose=false)
    open(filepath) do io
        load(io; verbose=verbose)
    end
end

function load(io::IOStream; verbose=true)
    tf = TiffFile(io)

    isdense = true
    ifds = IFD{offset(tf)}[]

    layout = nothing
    nplanes = 0

    for ifd in tf
        load!(tf, ifd)
        push!(ifds, ifd)

        new_layout = output(ifd)

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
        slice = view(BitArray(undef, layout.nbytes*8), :, 1)
    else
        slice = Array{layout.readtype}(undef, layout.nbytes÷sizeof(layout.readtype))
    end
    
    ifds_iter = Iterators.Stateful(ifds)

    # load first slice
    ifd = popfirst!(ifds_iter)
    trans = load(slice, tf, layout, ifd)

    # construct the final realized array from the lazy wrappers
    data = Array{eltype(trans)}(undef, size(trans)..., nplanes)
    plane_dim = length(size(data))
    # set the first plane to the data in trans
    selectdim(data, plane_dim, 1) .= trans

    freq = verbose ? 1 : Inf
    @showprogress freq for (idx, ifd) in enumerate(ifds_iter)
        trans = load(slice, tf, layout, ifd)
        selectdim(data, plane_dim, idx+1) .= trans
    end

    if layout.interpretation == PHOTOMETRIC_PALETTE
        maxdepth = 2^(first(ifd[BITSPERSAMPLE].data))-1
        colors = ifd[COLORMAP].data
        color_map = vec(reinterpret(RGB{N0f16}, reshape(colors, :, 3)'))
        data = IndirectArray(data, OffsetArray(color_map, 0:maxdepth))
    end

    close(tf.io)
    todrop = tuple(findall(size(data) .== 1)...)
    DenseTaggedImage(dropdims(data, dims=todrop), ifds)
end

"""
    load(prealloc, tf, layout, ifd)

Read the raw data from `tf` into `prealloc` and then lazily transform the latter
based on the information in `layout` and `ifd`. The returned array can later be
realized to unwrap the lazy transforms.
"""
function load(prealloc::AbstractVector, tf::TiffFile, layout::IFDLayout, ifd::IFD)
    read!(prealloc, tf, ifd)

    data = reinterpret(layout.rawtype, prealloc)

    trans = reshape(data, :, layout.nrows) 
    if layout.rawtype == Bool
        trans = view(trans, 1:layout.ncols, 1:layout.nrows)
    end

    if layout.nsamples > 1
        trans = PermutedDimsArray(reshape(trans, layout.nsamples, layout.ncols, layout.nrows), [1, 3, 2])
    else
        trans = PermutedDimsArray(trans, [2, 1])
    end

    colortype = nothing
    if layout.interpretation != PHOTOMETRIC_PALETTE
        if layout.interpretation == PHOTOMETRIC_MINISBLACK
            colortype = Gray{layout.mappedtype}
            if layout.nsamples > 1
                trans = view(trans, 1, :, :)
            end
        elseif layout.interpretation == PHOTOMETRIC_RGB
            colortype = RGB{layout.mappedtype}
            trans = view(trans, 1:3, :, :)
        else
            error("Given TIFF requests $(layout.interpretation) interpretation, but that's not yet supported")
        end
        trans = reinterpret(colortype, trans)
    end
    trans
end