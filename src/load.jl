function load(filepath::String; verbose=true)
    open(filepath) do io
        load(io; verbose=verbose)
    end
end

function load(io::IOStream; verbose=true)
    tf = read(io, TiffFile)

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

    loaded = load(tf, layout, ifds, Val(nplanes); verbose=verbose)
    
    if eltype(loaded) <: Palette
        ifd = ifds[1]
        raw = rawtype(ifd)
        loadedr = reinterpret(raw, loaded)
        maxdepth = 2^(first(ifd[BITSPERSAMPLE].data))-1
        colors = ifd[COLORMAP].data
        color_map = vec(reinterpret(RGB{N0f16}, reshape(colors, :, 3)'))
        data = IndirectArray(loadedr, OffsetArray(color_map, 0:maxdepth))
    elseif eltype(loaded) <: Bool
        data = Gray.(loaded)
    else
        data = loaded
    end

    close(tf.io)
    return DenseTaggedImage(data, ifds)
end

function load(tf::TiffFile, layout::IFDLayout, ifds, ::Val{1}; verbose = true)
    ifd = ifds[1]

    colortype, extras = interpretation(ifd)
    
    if layout.rawtype == Bool
        cache = BitArray(undef, ncols(ifd), nrows(ifd))
    else
        cache = Array{colortype{layout.mappedtype}}(undef, ncols(ifd), nrows(ifd))
    end
    
    read!(cache, tf, ifd)

    return Array(cache')
end

function load(tf::TiffFile, layout::IFDLayout, ifds, ::Val{N}; verbose = true) where {N}
    ifd = ifds[1]

    colortype, extras = interpretation(ifd)

    if layout.rawtype == Bool
        cache = BitArray(undef, ncols(ifd), nrows(ifd))
    else
        cache = Array{colortype{layout.mappedtype}}(undef, ncols(ifd), nrows(ifd))
    end

    data = similar(cache, nrows(ifd), ncols(ifd), N)

    freq = verbose ? 1 : Inf
    @showprogress freq for (idx, ifd) in enumerate(ifds)
        read!(cache, tf, ifd)
        data[:, :, idx] .= cache'
    end
    
    return data
end