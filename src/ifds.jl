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
    rawtype::DataType
    mappedtype::DataType
    interpretation::PhotometricInterpretations
end

IFDLayout() = IFDLayout(1,1,1, UInt16, N0f16, PHOTOMETRIC_MINISBLACK)

function output(tf::TiffFile, ifd::IFD)
    nrows = Int(get(tf, ifd[IMAGELENGTH])[1])
    ncols = Int(get(tf, ifd[IMAGEWIDTH])[1])

    samplesperpixel = Int(get(tf, getindex(ifd, SAMPLESPERPIXEL, 1))[1])
    sampleformats = get(tf, getindex(ifd, SAMPLEFORMAT, 1))

    interpretation = get(tf, ifd[PHOTOMETRIC])[1]

    strip_nbytes = get(tf, ifd[STRIPBYTECOUNTS])
    bitsperpixel = get(tf, getindex(ifd, BITSPERSAMPLE, 1))
    rawtypes = Set{DataType}()
    mappedtypes = Set{DataType}()
    for i in 1:samplesperpixel
        rawtype = rawtype_mapping[(SampleFormats(sampleformats[i]), bitsperpixel[i])]
        push!(rawtypes, rawtype)
        if rawtype <: Unsigned
            push!(mappedtypes, Normed{rawtype, sizeof(rawtype)*8})
        else
            push!(mappedtypes, rawtype)
        end
    end
    (length(rawtypes) > 1) && error("Variable per-pixel storage types are not yet supported")
    IFDLayout(
        samplesperpixel, nrows, ncols,
        Int(sum(strip_nbytes)),
        first(rawtypes),
        first(mappedtypes), 
        PhotometricInterpretations(interpretation))
end

function Base.read!(target::AbstractArray{T, N}, tf::TiffFile, ifd::IFD) where {T, N}
    layout = output(tf, ifd)

    rowsperstrip = get(tf, ifd[ROWSPERSTRIP])[1]
    nstrips = ceil(Int, layout.nrows / rowsperstrip)

    strip_nbytes = get(tf, ifd[STRIPBYTECOUNTS])
    strip_offsets = get(tf, ifd[STRIPOFFSETS])

    planarconfig = get(tf, getindex(ifd, PLANARCONFIG, 1))[1]
    (planarconfig != 1) && error("Images with data stored in planar format not yet supported")

    if nstrips > 1
        startbyte = 1
        for i in 1:nstrips
            seek(tf, strip_offsets[i])
            nbytes = Int(strip_nbytes[i] / sizeof(T))
            read!(tf, view(target, startbyte:(startbyte+nbytes-1)))
            startbyte += nbytes
        end
    else
        seek(tf, strip_offsets[1])
        read!(tf, target)
    end
end
