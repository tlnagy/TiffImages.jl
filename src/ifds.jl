"""
    $(TYPEDEF)

An image file directory is a sorted collection of the tags representing this
plane in the TIFF file. They behave like dictionaries, so given an IFD called
`ifd`, we can add new tags as follows:

```jldoctest; setup = :(ifd = TiffImages.IFD(UInt32))
julia> ifd[TiffImages.IMAGEDESCRIPTION] = "Some details";

julia> ifd[TiffImages.IMAGEWIDTH] = 512;

julia> ifd
IFD, with tags:
	Tag(IMAGEWIDTH, 512)
	Tag(IMAGEDESCRIPTION, "Some details")
```
"""
struct IFD{O <: Unsigned}
    tags::DefaultDict{UInt16, Vector{Tag}, DataType}
end

IFD(::Type{O}) where {O <: Unsigned} = IFD{O}(DefaultDict{UInt16, Vector{Tag}}(Vector{Tag}))
IFD(::Type{O}, tags) where {O <: Unsigned} = IFD{O}(tags)

"""
A wrapper to force getindex to return the underlying array instead of only the
first element. Usually the first element is sufficient, but sometimes access to
the array is needed (to add duplicate entries or access them).

```jldoctest; setup = :(ifd = TiffImages.IFD(UInt32))
julia> using TiffImages: Iterable

julia> ifd[TiffImages.IMAGEDESCRIPTION] = "test"
"test"

julia> ifd[Iterable(TiffImages.IMAGEDESCRIPTION)] # since wrapped with Iterable, returns array
1-element Vector{TiffImages.Tag}:
 Tag(IMAGEDESCRIPTION, "test")

julia> ifd[Iterable(TiffImages.IMAGEDESCRIPTION)] = "test2" # since wrapped with Iterable, it appends
"test2"

julia> ifd
IFD, with tags: 
	Tag(IMAGEDESCRIPTION, "test")
	Tag(IMAGEDESCRIPTION, "test2")

```
"""
struct Iterable{T}
    key::T
end

Base.length(ifd::IFD) = sum(map(length, values(ifd.tags)))
Base.keys(ifd::IFD) = keys(ifd.tags)
Base.iterate(ifd::IFD) = iterate(ifd.tags)
Base.iterate(ifd::IFD, n::Int) = iterate(ifd.tags, n)

Base.getindex(ifd::IFD, key::Iterable{TiffTag}) = getindex(ifd, Iterable(UInt16(key.key)))
Base.getindex(ifd::IFD, key::Iterable{UInt16}) = getindex(ifd.tags, key.key)
Base.getindex(ifd::IFD, key::TiffTag) = getindex(ifd, UInt16(key))
Base.getindex(ifd::IFD, key::UInt16) = first(getindex(ifd.tags, key))

Base.in(key::TiffTag, v::IFD) = in(UInt16(key), v)
Base.in(key::UInt16, v::IFD) = in(key, keys(v))
Base.delete!(ifd::IFD, key::TiffTag) = delete!(ifd, UInt16(key))
Base.delete!(ifd::IFD, key::UInt16) = delete!(ifd.tags, key)

Base.similar(::IFD{O}) where {O <: Unsigned} = IFD(O)
Base.merge(ifd::IFD{O}, other::IFD) where {O <: Unsigned} = IFD(O, DefaultDict(Vector{Int}, merge(ifd.tags, other.tags)))

Base.setindex!(ifd::IFD, value::Tag, key::UInt16) = setindex!(ifd.tags, [value], key)
Base.setindex!(ifd::IFD, value::Tag, key::TiffTag) = setindex!(ifd, value, UInt16(key))

Base.setindex!(ifd::IFD, value, key::TiffTag) = setindex!(ifd, value, UInt16(key))
Base.setindex!(ifd::IFD, value, key::UInt16) = setindex!(ifd, Tag(key, value), key)

Base.setindex!(ifd::IFD, value, key::Iterable{TiffTag}) = setindex!(ifd, value, Iterable(UInt16(key.key)))
Base.setindex!(ifd::IFD, value, key::Iterable{UInt16}) = setindex!(ifd, Tag(key.key, value), key)
Base.setindex!(ifd::IFD, value::Tag, key::Iterable{UInt16}) = push!(ifd.tags[key.key], value)

"""
    $SIGNATURES

Checks if the data in this IFD is contiguous on disk. Striped data can be read
faster as one contiguous chunk if possible.
"""
function iscontiguous(ifd::IFD)
    if !(ROWSPERSTRIP in ifd) || nrows(ifd) == ifd[ROWSPERSTRIP].data
        return true
    else
        return all(diff(ifd[STRIPOFFSETS].data) .== ifd[STRIPBYTECOUNTS].data[1:end-1])
    end
end

function load!(tf::TiffFile, ifd::IFD)
    for key in sort(collect(keys(ifd)))
        tags = ifd[Iterable(key)]
        for (idx, tag) in enumerate(tags)
            tags[idx] = load(tf, tag)
        end
    end
end

function Base.show(io::IO, ifd::IFD)
    print(io, "IFD, with tags: ")
    for key in sort(collect(keys(ifd)))
        tags = ifd[Iterable(key)]
        for tag in tags
            print(io, "\n\t", tag)
        end
    end
end

function Base.read(tf::TiffFile{O}, ::Type{IFD}) where O <: Unsigned
    # Regular TIFF's use 16bits instead of 32 bits for entry data
    N = O == UInt32 ? read(tf, UInt16) : read(tf, O)

    entries = IFD(O)

    for i in 1:N
        tag = read(tf, Tag)
        push!(entries[Iterable(tag.tag)], tag)
    end

    next_ifd = Int(read(tf, O))
    entries, next_ifd
end

function Base.iterate(file::TiffFile{O}) where {O}
    seek(file.io, file.first_offset)
    iterate(file, (read(file, IFD)))
end

"""
    iterate(file, state) -> IFD, Int

Advances the iterator to the next IFD.

**Output**
- `Vector{Int}`: Offsets within file for all strips corresponding to the current
   IFD
- `Int`: Offset of the next IFD
"""
function Base.iterate(file::TiffFile, state::Tuple{Union{IFD{O}, Nothing}, Int}) where {O}
    curr_ifd, next_ifd_offset = state
    # if current element doesn't exist, exit
    (curr_ifd == nothing) && return nothing
    (next_ifd_offset <= 0) && return (curr_ifd, (nothing, 0))

    seek(file.io, next_ifd_offset)
    next_ifd, next_ifd_offset = read(file, IFD)

    return (curr_ifd, (next_ifd, next_ifd_offset))
end

function Base.read!(target::AbstractArray{T, N}, tf::TiffFile, ifd::IFD) where {T, N}
    strip_offsets = ifd[STRIPOFFSETS].data

    if PLANARCONFIG in ifd
        planarconfig = ifd[PLANARCONFIG].data
        (planarconfig != 1) && error("Images with data stored in planar format not yet supported")
    end

    rows = nrows(ifd)
    cols = ncols(ifd)
    compression = COMPRESSION_NONE
    try 
        compression = CompressionType(ifd[COMPRESSION].data)
    catch
    end

    if !iscontiguous(ifd) || compression != COMPRESSION_NONE
        rowsperstrip = rows
        (ROWSPERSTRIP in ifd) && (rowsperstrip = ifd[ROWSPERSTRIP].data)
        nstrips = ceil(Int, rows / rowsperstrip)

        strip_nbytes = ifd[STRIPBYTECOUNTS].data

        if compression != COMPRESSION_NONE
            # strip_nbytes is the number of bytes pre-inflation so we need to
            # calculate the expected size once decompressed and update the values
            strip_nbytes = fill(rowsperstrip*cols*sizeof(T), length(strip_nbytes)::Int)
            strip_nbytes[end] = (rows - (rowsperstrip * (nstrips-1))) * cols * sizeof(T)
        end

        startbyte = 1
        for i in 1:nstrips
            seek(tf, strip_offsets[i]::Core.BuiltinInts)
            nbytes = Int(strip_nbytes[i]::Core.BuiltinInts / sizeof(T))
            read!(tf, view(target, startbyte:(startbyte+nbytes-1)), compression)
            startbyte += nbytes
        end
    else
        seek(tf, strip_offsets[1]::Core.BuiltinInts)
        read!(tf, target, compression)
    end
end

function Base.write(tf::TiffFile{O}, ifd::IFD{O}) where {O <: Unsigned}
    N = length(ifd)
    O == UInt32 ? write(tf, UInt16(N)) : write(tf, UInt64(N))

    # keep track of which tags are too large to fit in the IFD slot and need a
    # remote location for their data
    remotedata = Vector{Pair{Tag, Vector{Int}}}()
    sorted_keys = sort(collect(keys(ifd)))
    for k in sorted_keys
        tags = ifd[Iterable(k)]
        for tag in tags
            pos = position(tf.io)
            if !write(tf, tag)
                push!(remotedata, tag => [pos])
            end
        end
    end

    # end position, write a zero by default, but this should be updated if any
    # more IFDs are written
    ifd_end_pos = position(tf.io)
    write(tf, O(0))

    for (tag, poses) in remotedata
        tag = tag::Tag
        data_pos = position(tf.io)
        data = tag.data
        # add NUL terminator to the end of Strings that don't have it already
        if eltype(tag) === String
            data = data::SubString{String}
            if !endswith(data, '\0')
                data *= '\0'
            end
            write(tf, data)  # compile-time dispatch
        else
            write(tf, data)  # run-time dispatch
        end
        push!(poses, data_pos)
    end

    for (tag, poses) in remotedata
        tag = tag::Tag
        orig_pos, data_pos = poses
        seek(tf, orig_pos)
        write(tf, tag, data_pos)
    end

    seek(tf, ifd_end_pos)

    return ifd_end_pos
end
