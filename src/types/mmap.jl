"""
    $(TYPEDEF)

A type to represent memory-mapped TIFF data. Useful for opening and operating on
images too large to store in memory.

$(FIELDS)
"""
mutable struct DiskTaggedImage{T <: Colorant, O <: Unsigned, AA <: AbstractArray} <: AbstractDenseTIFF{T, 3}

    """
    Pointer to keep track of the backing file
    """
    file::TiffFile{O}
    """
    The associated tags for each slice in this array
    """
    ifds::Vector{IFD{O}}

    dims::NTuple{3, Int}

    """
    An internal cache to fill reading from disk
    """
    cache::AA

    """
    The index of the currently loaded slice
    """
    cache_index::Int

    last_ifd_offset::O

    """
    A flag tracking whether this file is editable
    """
    readonly::Bool

    function DiskTaggedImage(file::TiffFile{O}, ifds::Vector{IFD{O}}, dims, cache::AA, cache_index::Int, last_ifd_offset::O, readonly::Bool) where {O, AA <: AbstractArray}
        new{eltype(cache), O, typeof(cache)}(file, ifds, dims, cache, cache_index, last_ifd_offset, readonly)
    end
end

function DiskTaggedImage(file::TiffFile{O}, ifds::Vector{IFD{O}}) where {O}
    ifd = ifds[1]
    dims = (nrows(ifd), ncols(ifd), length(ifds))
    cache = getcache(ifd)
    DiskTaggedImage(file, ifds, dims, cache, -1, zero(O), true)
end

memmap(filepath, data) = DiskTaggedImage(getstream(format"TIFF", open(filepath, "w+"), filepath), data)

DiskTaggedImage(io::Stream, data::AbstractArray{T, 2}) where {T} = DiskTaggedImage(io, reshape(data, size(data)..., 1))
function DiskTaggedImage(io::Stream, data::AbstractArray{T, 3}) where {T}
    img = DenseTaggedImage(data)
    O = offset(img)
    tf = TiffFile{O}(io)

    last_ifd_offset = write(io, img)
    seekstart(io)
    tf = read(io, TiffFile)

    DiskTaggedImage(tf, img.ifds, size(img), getcache(img.ifds[1]), size(img, 3), O(last_ifd_offset), false)
end

Base.size(A::DiskTaggedImage) = A.dims

function Base.getindex(A::DiskTaggedImage{T, O, AA}, i1::Int, i2::Int, i::Int) where {T, O, AA}
    # check the loaded cache is already the correct slice
    if A.cache_index == i
        return A.cache[i2, i1]
    end

    ifd = A.ifds[i]

    # if the file isn't open, lets open a handle and update it
    if !isopen(A.file.io)
        path = A.file.filepath
        A.file.io = getstream(format"TIFF", open(path), path)
    end

    read!(A.cache, A.file, ifd)

    A.cache_index = i

    return A.cache[i2, i1]
end

function Base.setindex!(A::DiskTaggedImage, I...)
    error("This array is on disk and is read only. Convert to a mutable in-memory version by running "*
          "`copy(arr)`. \n\n𝗡𝗼𝘁𝗲: For large files this can be quite expensive. A future PR will add "*
          "support for reading and writing to/from disk.")
end

"""
    push!(img, slice)

Push a slice to a memory-mapped file. The slice must be the same `eltype` as the
target `img` and the `img` must be readonly.
"""
function Base.push!(A::DiskTaggedImage{T, O, AA}, data::AbstractArray{T, 2}) where {T, O, AA}
    (A.readonly) && error("This image is read only")
    @assert size(data) == (A.dims[1], A.dims[2]) "Pushed slices must have dimensions: $((A.dims[1], A.dims[2]))"

    ifd = _constructifd(data, offset(A.file))
    pagecache = Vector{UInt8}(undef, size(data, 2) * sizeof(T) * size(data, 1))

    seekend(A.file.io)
    prev_ifd_slice = _writeslice(pagecache, A.file, data, ifd, A.last_ifd_offset)

    # update data
    A.dims = (A.dims[1], A.dims[2], A.dims[3] + 1)
    push!(A.ifds, ifd)
    A.last_ifd_offset = prev_ifd_slice
    A.cache = data
    A.cache_index = A.dims[3]
    A
end