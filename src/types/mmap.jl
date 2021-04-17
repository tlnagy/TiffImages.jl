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

    """
    A flag tracking whether this file is editable
    """
    readonly::Bool

    function DiskTaggedImage(file::TiffFile{O}, ifds::Vector{IFD{O}}) where {O}
        ifd = ifds[1]
        dims = (nrows(ifd), ncols(ifd), length(ifds))
        cache = getcache(ifd)
        new{eltype(cache), O, typeof(cache)}(file, ifds, dims, cache, -1, false)
    end
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
