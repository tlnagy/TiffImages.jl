struct IFD{O <: Unsigned}
    tags::Dict{UInt16, Tag{O}}
end

Base.length(ifd::IFD) = length(ifd.tags)
Base.keys(ifd::IFD) = keys(ifd.tags)
Base.iterate(ifd::IFD) = iterate(ifd.tags)
Base.iterate(ifd::IFD, n::Integer) = iterate(ifd.tags, n)
Base.getindex(ifd::IFD, key::TiffTag) = getindex(ifd, UInt16(key))
Base.setindex!(ifd::IFD, value::Tag, key::UInt16) = setindex!(ifd.tags, value, key)
Base.in(key::TiffTag, v::Base.KeySet{UInt16, Dict{UInt16, Tag{O}}}) where {O} = in(UInt16(key), v)


function Base.getindex(ifd::IFD{O}, key::UInt16) where {O}
    if UInt16(key) in keys(ifd)
        return getindex(ifd.tags, key)
    else
        return Tag(UInt16(key), UInt8, O(1), UInt8[1], true)
    end
end

function load!(tf::TiffFile, ifd::IFD)
    for idx in keys(ifd)
        tag = ifd[idx]
        if !tag.loaded
            ifd[idx] = load(tf, tag)
        end
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

    k = keys(type_mapping)
    for i in 1:N
        tag = read(tf, Tag{O})
        entries[tag.tag] = tag
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
    nrows = Int(first(ifd[IMAGELENGTH].data))
    ncols = Int(first(ifd[IMAGEWIDTH].data))

    samplesperpixel = first(ifd[SAMPLESPERPIXEL].data)
    sampleformats = ifd[SAMPLEFORMAT].data

    if length(sampleformats) == 1 && samplesperpixel > 1
        sampleformats = fill(sampleformats[1], samplesperpixel)
    end

    interpretation = first(ifd[PHOTOMETRIC].data)

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

    compression = CompressionType(first(ifd[COMPRESSION].data))

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
    (ROWSPERSTRIP in keys(ifd)) && (rowsperstrip = first(ifd[ROWSPERSTRIP].data))
    nstrips = ceil(Int, layout.nrows / rowsperstrip)

    strip_nbytes = ifd[STRIPBYTECOUNTS].data

    if layout.compression != COMPRESSION_NONE
        # strip_nbytes is the number of bytes pre-inflation so we need to
        # calculate the expected size once decompressed and update the values
        fill!(strip_nbytes, rowsperstrip*layout.ncols)
        strip_nbytes[end] = (layout.nrows - (rowsperstrip * (nstrips-1))) * layout.ncols
    end

    strip_offsets = ifd[STRIPOFFSETS].data

    planarconfig = first(ifd[PLANARCONFIG].data)
    (planarconfig != 1) && error("Images with data stored in planar format not yet supported")

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
