"""
    $(TYPEDEF)

A type to represent memory-mapped TIFF data. Useful for opening and operating on
images too large to store in memory.

```jldoctest
julia> using TiffImages, ColorTypes

julia> img = TiffImages.memmap(Gray{Float32}, joinpath(mktempdir(), "test.tif"))
32-bit DiskTaggedImage{Gray{Float32}} 0×0×0 (writable)
    Current file size on disk:   8 bytes
    Addressable space remaining: 4.000 GiB
```

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
    Position of last loaded IFD, updated whenever a slice is appended
    """
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

"""
    memmap(T, filepath; bigtiff)

Create a new memory-mapped file ready with element type `T` for appending future
slices. The `bigtiff` flag, if true, allows 64-bit offsets for data larger than
~4GB. 

```jldoctest; setup=:(rm("test.tif", force=true))
julia> using ColorTypes, FixedPointNumbers # for Gray{N0f8} type

julia> img = memmap(Gray{N0f8}, "test.tif"); # make memory-mapped image

julia> push!(img, rand(Gray{N0f8}, 100, 100)); 

julia> push!(img, rand(Gray{N0f8}, 100, 100)); 

julia> size(img)
(100, 100, 2)
```
"""
function memmap(::Type{T}, filepath; bigtiff=false) where {T <: Colorant}
    if isfile(filepath)
        error("This file already exists, please use `TiffImages.load` to open")
    end
    DiskTaggedImage(T, getstream(format"TIFF", open(filepath, "w+"), filepath); bigtiff = bigtiff)
end

function DiskTaggedImage(::Type{T}, io::Stream; bigtiff = false) where {T}
    O = bigtiff ? UInt64 : UInt32
    tf = TiffFile{O}(io)

    last_ifd_offset = write(tf) # write out header

    DiskTaggedImage(tf, IFD{O}[], (0, 0, 0), Array{T}(undef, 1, 1), -1, O(last_ifd_offset), false)
end

Base.size(A::DiskTaggedImage) = A.dims
offset(::DiskTaggedImage{T, O, AA}) where {T, O, AA} = O

function Base.getindex(A::DiskTaggedImage{T, O, AA}, i1::Int, i2::Int, i::Int) where {T, O, AA}
    (size(A) == (0, 0, 0)) && error("This image has not been initialized, please `push!` data into it first")
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
    error("Unable to mutate inplace since this array is on disk. Convert to a mutable in-memory version by running "* 
          "`copy(arr)`. \n\n𝗡𝗼𝘁𝗲: For large files this can be quite expensive. A future PR will add "*
          "support for writing inplace to disk. See `push!` for appending to an array.")
end

"""
    push!(img::DiskTaggedImage, slice::AbstractMatrix)

Push a 2D slice to a memory-mapped file. The slice must be the same `eltype` as the
target `img` and the `img` must be not be readonly.
"""
function Base.push!(A::DiskTaggedImage{T, O, AA}, data::AbstractMatrix{T}) where {T, O, AA}
    (A.readonly) && error("This image is read only")

    if size(A) == (0, 0, 0) # if this is the initial slice pushed, initialize the size
        A.dims = (size(data)..., 0) 
    end

    @assert size(data) == (A.dims[1], A.dims[2]) "Pushed slices must have dimensions: $((A.dims[1], A.dims[2]))"

    ifd = _constructifd(data, offset(A.file))
    pagecache = Vector{UInt8}(undef, size(data, 2) * sizeof(T) * size(data, 1))

    if A.last_ifd_offset + sizeof(pagecache) + sizeof(ifd) > typemax(O)
        @info "No more room in file @ N = $(length(A.ifds))"
    end
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

Base.push!(A::DenseTaggedImage{T, N, O, AA}, data) where {T, N, O, AA <: DiskTaggedImage} = push!(A.data, data)

function Base.show(io::IO, ::MIME"text/plain", A::DiskTaggedImage{T, O, AA}) where {T, O, AA}
    printstyled(io, O == UInt32 ? "32-bit" : "64-bit"; color = :cyan)
    print(io, " DiskTaggedImage{$(T)} ")
    printstyled(io, "$(size(A, 1))×$(size(A, 2))×$(size(A, 3))"; bold=true)
    if A.readonly
        printstyled(io, " (readonly)"; color=:red)
    else
        printstyled(io, " (writable)"; color=:green)
    end
    println(io)
    ondisk = sizeof(A.file)
    ondisk += (size(A) == (0, 0, 0)) ? 0 : sum(sizeof.(A.ifds)) + sizeof(T) * reduce(*, size(A))
    println(io, "    Current file size on disk:   $(Base.format_bytes(ondisk))")
    println(io, "    Addressable space remaining: $(Base.format_bytes(typemax(O) - ondisk))")
end
