struct IFD{O <: Unsigned}
    tags::Dict{UInt16, Tag{O}}
end

Base.length(ifd::IFD) = length(ifd.tags)
Base.keys(ifd::IFD) = keys(ifd.tags)
Base.iterate(ifd::IFD) = iterate(ifd.tags)
Base.iterate(ifd::IFD, n::Integer) = iterate(ifd.tags, n)
Base.getindex(ifd::IFD, key) = getindex(ifd.tags, key)
Base.getindex(ifd::IFD, key::TiffTag) = getindex(ifd.tags, UInt16(key))

function Base.getindex(ifd::IFD{O}, key::TiffTag, default::T) where {O, T <: Integer}
    if UInt16(key) in keys(ifd)
        return getindex(ifd, key)
    else
        return Tag(UInt16(key), O, O(1), O(default))
    end
end

function Base.show(io::IO, ifd::IFD)
    println(io, "IFD, with tags: (* indicates remote data)")
    for tag in sort(collect(keys(ifd)))
        println(io, "\t", ifd[tag])
    end
end

function Base.read(tf::TiffFile, ::Type{IFD{O}}) where O <: Unsigned
    # Regular TIFF's use 16bits instead of 32 bits for entry data
    N = O == UInt32 ? read(tf, UInt16) : read(tf, O)

    entries = Dict{UInt16, Tag{O}}()

    # tag_info = Array{UInt16}(undef, 2)
    # data_info = Array{O}(undef, 2)

    k = keys(type_mapping)
    for i in 1:N
        tag = read(tf, Tag{O})
        entries[tag.tag] = tag
        # read!(tf, tag_info)
        # read!(tf, data_info)
        # if tag_info[2] in k
        #     entries[tag_info[1]] = Tag(tag_info[1], type_mapping[tag_info[2]], data_info...)
        # end
    end

    next_ifd = Int(read(tf, O))
    IFD(entries), next_ifd
end


function Base.iterate(file::TiffFile{O}) where {O}
    seek(file.io, file.first_offset)
    iterate(file, (read(file, IFD{O})))
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
    next_ifd, next_ifd_offset = read(file, IFD{O})

    return (curr_ifd, (next_ifd, next_ifd_offset))
end

function Base.read!(target::AbstractArray, tf::TiffFile, ifd::IFD)
    nrows = get(tf, ifd[IMAGELENGTH])[1]
    ncols = get(tf, ifd[IMAGEWIDTH])[1]

    rowsperstrip = get(tf, ifd[ROWSPERSTRIP])[1]
    nstrips = ceil(Int, nrows / rowsperstrip)

    strip_nbytes = get(tf, ifd[STRIPBYTECOUNTS])
    strip_offsets = get(tf, ifd[STRIPOFFSETS])

    interpretation = get(tf, ifd[PHOTOMETRIC])[1]
    conv = Gray

    bitsperpixel = get(tf, getindex(ifd, BITSPERSAMPLE, 1))[1]
    rawtype = UInt16
    mappedtype = Normed{rawtype, Int(bitsperpixel)}

    samplesperpixel = get(tf, getindex(ifd, SAMPLESPERPIXEL, 1))
    sampleformat = get(tf, getindex(ifd, SAMPLEFORMAT, 1))

    planarconfig = get(tf, getindex(ifd, PLANARCONFIG, 1))[1]
    (planarconfig != 1) && error("Images with data stored in planar format not yet supported")

    if nstrips > 1
        for i in 1:nstrips
            seek(tf, strip_offsets[i])
            read!(tf, view(target, :, i))
        end
    else
        seek(tf, strip_offsets[1])
        read!(tf, vec(target))
    end
end


