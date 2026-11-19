"""
    $(SIGNATURES)

Loads a TIFF image. Optional flags `verbose`, `lazyio`, and `mmap` are set to
true, false, and false by default, respectively. Setting `verbose` to false
will hide the loading bar, while setting either `lazyio` or `mmap` to true
defer loading until the data are needed (by either of two mechanisms).

Parallelism is enabled by default, but can be disabled by setting
`JULIA_IMAGES_PARALLEL`=false in your environment

Loading images with a large number of channels may result in a noticeable delay
on the first load (up to several minutes for hundreds or thousands of channels)

See [Lazy TIFFs](@ref) for more details about memory-mapping and lazy I/O.
"""
function load(filepath::String; mode = "r", kwargs...)
    _safe_open(filepath, mode) do io
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

    homogeneous = is_homogeneous(ifds)

    ifd = first(ifds)
    if mmap && iscontiguous(ifd) && getdata(CompressionType, ifd, COMPRESSION, COMPRESSION_NONE) === COMPRESSION_NONE
        return MmappedTIFF(tf, ifds)
    elseif lazyio || mmap
        homogeneous || error("lazy IO is only supported for homogeneous files")
        mmap && @warn "Compression and discontiguous planes are not supported by `mmap`, use `lazyio = true` instead"
        loaded = LazyBufferedTIFF(tf, ifds)
    else
        if nplanes == 1
            loaded = load(tf, ifds, nothing; verbose=verbose)
        else
            loaded = load(tf, ifds, nplanes, Val(homogeneous); verbose=verbose)
        end
    end

    if (tf.need_bswap && !is_irregular_bps(ifd)) || predictor(ifd) == 3
        @debug "bswap'ing data"
        if !homogeneous
            for sub in loaded
                sub .= _bswap.(sub)
            end
        else
            loaded .= _bswap.(loaded)
        end
    end

    close(tf.io)

    if nplanes > 1 && !homogeneous
        # multiple images of different sizes or color types
        data = fixcolors.(loaded, ifds)
        return StridedTaggedImage(data, ifds)
    else
        data = fixcolors(loaded, first(ifds))
        return DenseTaggedImage(data, ifds)
    end
end

"""
    fixcolors(loaded, ifd)

Wrap the raw eltype of an image with color if needed, e.g. for space efficient
on-disk representations like palette-colored images. Otherwise, just return the passed image.
"""
function fixcolors(loaded, ifd)
    if eltype(loaded) <: Palette
        raw = rawtype(ifd)
        loadedr = reinterpret(raw, loaded)
        maxdepth = 2^(Int(ifd[BITSPERSAMPLE].data))-1
        colors = ifd[COLORMAP].data
        color_map = vec(reinterpret(RGB{N0f16}, reshape(colors, :, 3)'))
        return IndirectArray(loadedr, OffsetArray(color_map, 0:maxdepth))
    else
        return loaded
    end
end

function load(tf::TiffFile, ifds::AbstractVector{<:IFD}, ::Nothing; verbose = true)
    ifd = first(ifds)

    cache = _getcache(ifd)
    read!(cache, tf, ifd)
    transform!(similar(cache, nrows(ifd), ncols(ifd)), cache, ifd)
end

function load(tf::TiffFile, ifds::AbstractVector{<:IFD}, N, homogeneous::Val{true}; verbose = true)
    ifd = first(ifds)

    cache = _getcache(ifd)

    data = similar(cache, nrows(ifd), ncols(ifd), N)

    @showprogress desc="Loading:" enabled=verbose for (idx, ifd) in enumerate(ifds)
        read!(cache, tf, ifd)
        transform!(view(data, :, :, idx), cache, ifd)
    end

    return data
 end

function load(tf::TiffFile, ifds::AbstractVector{<:IFD}, N, homogeneous::Val{false}; verbose = true)
    data = Vector{AbstractMatrix}()

    @showprogress desc="Loading:" enabled=verbose for (idx, ifd) in enumerate(ifds)
        cache = _getcache(ifd)
        read!(cache, tf, ifd)
        push!(data, transform(cache, ifd))
    end

    return data
end

function _getcache(ifd)
    spp = nsamples(ifd)
    if spp > 100
        @info "loading image with $spp channels; this may take up to a few minutes"
    end

    getcache(ifd)
end

transform(cache, ifd) = istiled(ifd) ? tile(cache, ifd) : cache'

"""
    transform!(out, cache, ifd)

Write the decoded `cache` for `ifd` into `out`, which must be an
`nrows(ifd)` × `ncols(ifd)` matrix, without allocating intermediates.
"""
function transform!(out::AbstractMatrix, cache, ifd)
    if istiled(ifd)
        tile!(out, cache, ifd)
    else
        out .= cache'
    end
    out
end

tile(cache, ifd) = tile!(similar(cache, nrows(ifd), ncols(ifd)), cache, ifd)

"""
    tile!(out, cache, ifd)

Reassemble the tiles decoded into `cache` into the `nrows(ifd)` × `ncols(ifd)`
matrix `out`. Tiles are stored one after another in `cache`, ordered
row-major across the image, and each tile is itself stored row-major. Tiles on
the right and bottom edges are padded during encoding; the padding is skipped.
"""
function tile!(out::AbstractMatrix, cache::AbstractArray, ifd)
    rows = nrows(ifd)
    cols = ncols(ifd)
    width = tilecols(ifd) # width of a tile
    height = tilerows(ifd) # height of a tile
    tileswidth = cld(cols, width) # number of tiles in a row
    tilesheight = cld(rows, height) # number of tiles in a column
    tilesize = width * height # number of pixels in a tile

    size(out) == (rows, cols) || throw(DimensionMismatch("output has size $(size(out)), expected $((rows, cols))"))
    length(cache) >= tileswidth * tilesheight * tilesize || throw(DimensionMismatch("cache is too small for $(tileswidth * tilesheight) tiles"))

    _tile!(out, cache, rows, cols, width, height, tileswidth, tilesheight)
end

function _tile!(out, cache, rows, cols, width, height, tileswidth, tilesheight)
    tilesize = width * height
    @inbounds for tr in 0:tilesheight-1, tc in 0:tileswidth-1
        base = (tr * tileswidth + tc) * tilesize # linear offset of this tile in `cache`
        r0 = tr * height
        c0 = tc * width
        nr = min(height, rows - r0) # crop edge tiles
        nc = min(width, cols - c0)
        for i in 1:nr
            rowbase = base + (i - 1) * width
            for j in 1:nc
                out[r0 + i, c0 + j] = cache[rowbase + j]
            end
        end
    end
    out
end