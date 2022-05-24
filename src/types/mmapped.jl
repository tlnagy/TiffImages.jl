struct MmappedTIFF{T <: Colorant, N, O <: Unsigned, A <: AbstractMatrix{T}} <: AbstractTIFF{T, N}
    """
    2d slices in the file"
    """
    chunks::Vector{A}
    """
    The associated tags for each slice in this array
    """
    ifds::Vector{IFD{O}}
    """
    The 2d slice size
    """
    sz2::Dims{2}
end

function MmappedTIFF{T,N}(file::TiffFile{O}, ifds::Vector{IFD{O}}) where {T, N, O <: Unsigned}
    N ∈ (2, 3) || error("only 2d and 3d TIFF arrays are supported")
    if N == 2
        length(ifds) == 1 || error("2d files must have a single Image File Directory")
    end
    ifd = first(ifds)
    sz = (nrows(ifd), ncols(ifd))
    compression = getdata(CompressionType, ifd, COMPRESSION, COMPRESSION_NONE)
    compression == COMPRESSION_NONE || error("mmap is not yet supported with compression")
    all(iscontiguous, ifds) || error("non-contiguous TIFFs are not yet supported by mmap")

    seek(file, 0)
    rawio = stream(file)
    raw = Mmap.mmap(rawio, Vector{UInt8}, filesize(rawio))
    chunks = [getchunk(T, raw, reverse(sz), ifd) for ifd in ifds]
    return MmappedTIFF{T, N, O, eltype(chunks)}(chunks, ifds, sz)
end

function MmappedTIFF{T}(file::TiffFile{O}, ifds::Vector{IFD{O}}) where {T, O <: Unsigned}
    l = length(ifds)
    return l == 1 ? MmappedTIFF{T, 2}(file, ifds) : MmappedTIFF{T, 3}(file, ifds)
end

function MmappedTIFF(file::TiffFile{O}, ifds::Vector{IFD{O}}) where {O <: Unsigned}
    ifd = first(ifds)
    T = rawtype(ifd)
    colortype, _ = interpretation(ifd)
    return MmappedTIFF{colortype{_mappedtype(T)}}(file, ifds)
end

function getchunk(::Type{T}, raw::Vector{UInt8}, sz::Dims{2}, ifd::IFD) where T
    rawsz = sizeof(T) * prod(sz)
    strip_offsets = ifd[STRIPOFFSETS].data
    o = strip_offsets[1]::Core.BuiltinInts
    if sizeof(T) == 1
        return reinterpret(reshape, T, reshape(view(raw, o+1:o+rawsz), sz...))
    end
    return reinterpret(reshape, T, reshape(view(raw, o+1:o+rawsz), sizeof(T), sz...))
end

## AbstractArray interface

chunk1(img::MmappedTIFF) = @inbounds return img.chunks[1]

Base.size(img::MmappedTIFF{T, 2}) where T = img.sz2
Base.size(img::MmappedTIFF{T, 3}) where T = (img.sz2..., length(img.chunks))

Base.@propagate_inbounds Base.getindex(img::MmappedTIFF{T, 2}, i::Int, j::Int) where T = chunk1(img)[j, i]

Base.@propagate_inbounds function Base.getindex(img::MmappedTIFF{T, 3}, i::Int, j::Int, k::Int) where T
    chunk = img.chunks[k]
    return chunk[j, i]
end

# These work only if the file was opened with write permissions
Base.@propagate_inbounds Base.setindex!(img::MmappedTIFF{T, 2}, val, i::Int, j::Int) where T = chunk1(img)[j, i] = val

Base.@propagate_inbounds function Base.setindex!(img::MmappedTIFF{T, 3}, val, i::Int, j::Int, k::Int) where T
    chunk = img.chunks[k]
    chunk[j, i] = val
end
