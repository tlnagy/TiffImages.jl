"""
    $(SIGNATURES)

Loads a TIFF image. Optional flags `verbose` and `mmap` are set to true and
false by default, respectively. Setting the former to false will hide the
loading bar, while setting the later to true will memory-mapped the image.

See [Memory-mapping TIFFs](@ref) for more details about memory-mapping
"""
function load(filepath::String; verbose=true, mmap = false)
    open(filepath) do io
        load(io; verbose=verbose, mmap=mmap)
    end
end

load(io::IOStream; verbose=true, mmap = false) = load(read(io, TiffFile); verbose=verbose, mmap=mmap)
function load(tf::TiffFile; verbose=true, mmap = false)
    ifds = IFD{offset(tf)}[]

    nplanes = 0
    for ifd in tf
        load!(tf, ifd)
        push!(ifds, ifd)
        nplanes += 1
    end

    if mmap
        loaded = DiskTaggedImage(tf, ifds)
    else
        if nplanes == 1
            loaded = load(tf, ifds, nothing; verbose=verbose)
        else
            loaded = load(tf, ifds, nplanes; verbose=verbose)
        end
    end
    data = fixcolors(loaded, first(ifds))

    close(tf.io)
    return DenseTaggedImage(data, ifds)
end

"""
    fixcolors(loaded, ifd)

Wrap the raw eltype of an image with color if needed, e.g. for space efficient
on-disk representations like palette-colored images and bitarrays. Otherwise,
just return the passed image. 
"""
function fixcolors(loaded, ifd)
    if eltype(loaded) <: Palette
        raw = rawtype(ifd)
        loadedr = reinterpret(raw, loaded)
        maxdepth = 2^(Int(ifd[BITSPERSAMPLE].data))-1
        colors = ifd[COLORMAP].data
        color_map = vec(reinterpret(RGB{N0f16}, reshape(colors, :, 3)'))
        return IndirectArray(loadedr, OffsetArray(color_map, 0:maxdepth))
    elseif eltype(loaded) <: Bool
        return Gray.(loaded)
    else
        return loaded
    end
end

function load(tf::TiffFile, ifds::AbstractVector{<:IFD}, ::Nothing; verbose = true)
    ifd = ifds[1]
    cache = getcache(ifd)
    read!(cache, tf, ifd)

    return Matrix(cache')
end

function load(tf::TiffFile, ifds::AbstractVector{<:IFD}, N; verbose = true)
    ifd = ifds[1]

    cache = getcache(ifd)

    data = similar(cache, nrows(ifd), ncols(ifd), N)

    freq = verbose ? 1 : Inf
    @showprogress freq for (idx, ifd) in enumerate(ifds)
        read!(cache, tf, ifd)
        data[:, :, idx] .= cache'
    end

    return data
end