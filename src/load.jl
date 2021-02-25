function load(filepath::String; verbose=true, mmap = false)
    open(filepath) do io
        load(io; verbose=verbose, mmap=mmap)
    end
end

function load(io::IOStream; verbose=true, mmap = false)
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

    if mmap
        loaded = DiskTaggedImage(tf, ifds)
    else
        loaded = load(tf, ifds, Val(nplanes); verbose=verbose)
    end

    if eltype(loaded) <: Palette
        ifd = ifds[1]
        raw = rawtype(ifd)
        loadedr = reinterpret(raw, loaded)
        maxdepth = 2^(Int(ifd[BITSPERSAMPLE].data))-1
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

function load(tf::TiffFile, ifds, ::Val{1}; verbose = true)
    ifd = ifds[1]
    cache = getcache(ifd)
    read!(cache, tf, ifd)

    return Array(cache')
end

function load(tf::TiffFile, ifds, ::Val{N}; verbose = true) where {N}
    ifd = ifds[1]

    caches = [getcache(ifd) for _ in 1:Threads.nthreads()]

    data = similar(caches[1], nrows(ifd), ncols(ifd), N)

    freq = verbose ? 1 : Inf
    p = Progress(length(ifds); dt=freq)
    Threads.@threads for idx in 1:length(ifds)
        tid = Threads.threadid()
        read!(caches[tid], tf, ifds[idx])
        data[:, :, idx] .= caches[tid]'
        next!(p)
    end

    return data
end