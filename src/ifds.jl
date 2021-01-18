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
    tags::OrderedDict{UInt16, Tag}
end

IFD(o::Type{O}) where {O <: Unsigned} = IFD{O}(OrderedDict{UInt16, Tag}())

Base.length(ifd::IFD) = length(ifd.tags)
Base.keys(ifd::IFD) = keys(ifd.tags)
Base.iterate(ifd::IFD) = iterate(ifd.tags)
Base.iterate(ifd::IFD, n::Integer) = iterate(ifd.tags, n)
Base.getindex(ifd::IFD, key::TiffTag) = getindex(ifd, UInt16(key))
Base.getindex(ifd::IFD{O}, key::UInt16) where {O} = getindex(ifd.tags, key)
Base.in(key::TiffTag, v::IFD) = in(UInt16(key), v)
Base.in(key::UInt16, v::IFD) = in(key, keys(v))
Base.delete!(ifd::IFD, key::TiffTag) = delete!(ifd, UInt16(key))
Base.delete!(ifd::IFD, key::UInt16) = delete!(ifd.tags, key)

Base.setindex!(ifd::IFD, value::Tag, key::UInt16) = setindex!(ifd.tags, value, key)
Base.setindex!(ifd::IFD, value::Tag, key::TiffTag) = setindex!(ifd.tags, value, UInt16(key))

Base.setindex!(ifd::IFD, value, key::TiffTag) = setindex!(ifd, value, UInt16(key))
function Base.setindex!(ifd::IFD{O}, value, key::UInt16) where {O <: Unsigned}
    setindex!(ifd, Tag(key, value), UInt16(key))
end


function load!(tf::TiffFile, ifd::IFD)
    for idx in keys(ifd)
        ifd[idx] = load(tf, ifd[idx])
    end
end

function Base.show(io::IO, ifd::IFD)
    print(io, "IFD, with tags: ")
    for tag in sort(collect(keys(ifd)))
        print(io, "\n\t", ifd[tag])
    end
end

function Base.read(tf::TiffFile{O}, ::Type{IFD}) where O <: Unsigned
    # Regular TIFF's use 16bits instead of 32 bits for entry data
    N = O == UInt32 ? read(tf, UInt16) : read(tf, O)

    entries = OrderedDict{UInt16, Tag}()

    for i in 1:N
        tag = read(tf, Tag)
        entries[tag.tag] = tag
    end

    next_ifd = Int(read(tf, O))
    IFD{O}(entries), next_ifd
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

struct IFDLayout
    nsamples::Int
    nrows::Int
    ncols::Int
    nbytes::Int
    readtype::DataType
    rawtype::DataType
    mappedtype::DataType
    compression::CompressionType
    interpretation::PhotometricInterpretations
end

function output(ifd::IFD)
    nrows = Int(ifd[IMAGELENGTH].data)
    ncols = Int(ifd[IMAGEWIDTH].data)

    samplesperpixel = Int(ifd[SAMPLESPERPIXEL].data)
    sampleformats = fill(UInt16(0x01), samplesperpixel)
    if SAMPLEFORMAT in ifd
        sampleformats = ifd[SAMPLEFORMAT].data
    end

    interpretation = Int(ifd[PHOTOMETRIC].data)

    strip_nbytes = ifd[STRIPBYTECOUNTS].data
    nbytes = Int(sum(strip_nbytes))
    bitsperpixel = ifd[BITSPERSAMPLE].data
    rawtypes = Set{DataType}()
    mappedtypes = Set{DataType}()
    for i in 1:samplesperpixel
        rawtype = rawtype_mapping[(SampleFormats(sampleformats[i]), bitsperpixel[i])]
        push!(rawtypes, rawtype)
        if rawtype <: Unsigned
            push!(mappedtypes, Normed{rawtype, sizeof(rawtype)*8})
        elseif rawtype <: Signed
            push!(mappedtypes, Fixed{rawtype, sizeof(rawtype)*8-1})
        else
            push!(mappedtypes, rawtype)
        end
    end
    (length(rawtypes) > 1) && error("Variable per-pixel storage types are not yet supported")
    rawtype = first(rawtypes)
    readtype = rawtype

    compression = COMPRESSION_NONE
    if COMPRESSION in ifd
        compression = CompressionType(ifd[COMPRESSION].data)
    end

    if compression != COMPRESSION_NONE
        # recalculate nbytes if the data is compressed since the inflated data
        # is most likely larger than the bytes on disk
        nbytes = nrows*ncols*samplesperpixel*sizeof(rawtype)
        readtype = UInt8
    end

    IFDLayout(
        samplesperpixel, nrows, ncols,
        nbytes,
        readtype,
        rawtype,
        first(mappedtypes),
        compression,
        PhotometricInterpretations(interpretation))
end

function Base.read!(target::AbstractArray{T, N}, tf::TiffFile, ifd::IFD) where {T, N}
    layout = output(ifd)

    rowsperstrip = layout.nrows
    (ROWSPERSTRIP in keys(ifd)) && (rowsperstrip = ifd[ROWSPERSTRIP].data)
    nstrips = ceil(Int, layout.nrows / rowsperstrip)

    strip_nbytes = ifd[STRIPBYTECOUNTS].data

    if layout.compression != COMPRESSION_NONE
        # strip_nbytes is the number of bytes pre-inflation so we need to
        # calculate the expected size once decompressed and update the values
        strip_nbytes = fill(rowsperstrip*layout.ncols, length(strip_nbytes))
        strip_nbytes[end] = (layout.nrows - (rowsperstrip * (nstrips-1))) * layout.ncols
    end

    strip_offsets = ifd[STRIPOFFSETS].data

    if PLANARCONFIG in ifd
        planarconfig = ifd[PLANARCONFIG].data
        (planarconfig != 1) && error("Images with data stored in planar format not yet supported")
    end

    if nstrips > 1
        startbyte = 1
        for i in 1:nstrips
            seek(tf, strip_offsets[i])
            nbytes = Int(strip_nbytes[i] / sizeof(T))
            read!(tf, view(target, startbyte:(startbyte+nbytes-1)), layout.compression)
            startbyte += nbytes
        end
    else
        seek(tf, strip_offsets[1])
        read!(tf, target, layout.compression)
    end
end

function Base.write(tf::TiffFile{O}, ifd::IFD{O}) where {O <: Unsigned}
    N = length(ifd)
    O == UInt32 ? write(tf, UInt16(N)) : write(tf, UInt64(N))

    sort!(ifd.tags)

    # keep track of which tags are too large to fit in the IFD slot and need a
    # remote location for their data
    remotedata = OrderedDict{Tag, Vector{Int}}()
    for (key, tag) in ifd
        pos = position(tf.io)
        if !write(tf, tag)
            remotedata[tag] = [pos]
        end
    end

    # end position, write a zero by default, but this should be updated if any
    # more IFDs are written
    ifd_end_pos = position(tf.io)
    write(tf, O(0))

    for (tag, poses) in remotedata
        data_pos = position(tf.io)
        # add NUL terminator to the end of Strings that don't have it already
        data = (eltype(tag) == String && !endswith(tag.data, '\0')) ? tag.data * "\0" : tag.data
        write(tf, data)
        push!(poses, data_pos)
    end

    for (tag, poses) in remotedata
        orig_pos, data_pos = poses
        seek(tf, orig_pos)
        write(tf, tag, data_pos)
    end

    seek(tf, ifd_end_pos)

    return ifd_end_pos
end