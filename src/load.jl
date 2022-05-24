"""
    $(SIGNATURES)

Loads a TIFF image. Optional flags `verbose` and `mmap` are set to true and
false by default, respectively. Setting the former to false will hide the
loading bar, while setting the later to true will memory-mapped the image.

See [Lazy TIFFs](@ref) for more details about memory-mapping and lazy I/O.
"""
function load(filepath::String; mode = "r", kwargs...)
    open(filepath, mode) do io
        load(io; kwargs...)
    end
end

load(io::IOStream; kwargs...) = load(read(io, TiffFile); kwargs...)
function load(tf::TiffFile; verbose=true, mmap = false, lazyio = false)
    ifds = IFD{offset(tf)}[]

    nplanes = 0
    for ifd in tf
        load!(tf, ifd)
        push!(ifds, ifd)
        nplanes += 1
    end

    ifd = first(ifds)
    if mmap && iscontiguous(ifd) && getdata(CompressionType, ifd, COMPRESSION, COMPRESSION_NONE) === COMPRESSION_NONE
        return MmappedTIFF(tf, ifds)
    elseif lazyio || mmap
        mmap && @warn "Compression and discontiguous planes are not supported by `mmap`, use `lazyio = true` instead" maxlog=1
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