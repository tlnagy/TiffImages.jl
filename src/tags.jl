"""
    $(TYPEDEF)

In-memory representation of Tiff Tags, which are essentially key value pairs.
The `data` field can either be a `String`, a `Number`, an Array of bitstypes, or
a [`RemoteData`](@ref) type.

$FIELDS
"""
struct Tag{T}
    tag::UInt16
    data::T
end

Tag(tag::TiffTag, data) = Tag(UInt16(tag), data)
Tag(tag::UInt16, data::String) = Tag{String}(tag, data)
Tag(tag::UInt16, data::T) where {T <: Enum} = Tag{UInt16}(tag, UInt16(data))
function Tag(tag::UInt16, data::AbstractVector{T}) where {T}
    if length(data) == 1
        Tag{T}(tag, first(data))
    else
        Tag{Vector{T}}(tag, data)
    end
end

function Base.getproperty(t::Tag{<: AbstractString}, f::Symbol)
    if f == :data
        # strip NUL terminators from the end of strings
        strip(getfield(t, :data), '\0')
    else
        getfield(t, f)
    end
end

Base.length(t::Tag{<: AbstractVector}) = length(t.data)
Base.length(t::Tag{<: AbstractString}) = (endswith(t.data, '\0') ? length(t.data) : length(t.data) + 1)
Base.length(t::Tag) = 1

Base.eltype(::Tag{T}) where {T} = T
Base.eltype(::Tag{<: AbstractVector{T}}) where {T} = T
Base.eltype(t::Tag{RemoteData}) = t.data.datatype

load(tf::TiffFile, t::Tag) = t

function load(tf::TiffFile{O}, t::Tag{RemoteData{O}}) where {O <: Unsigned}
    T = t.data.datatype
    N = t.data.count
    rawdata = Vector{UInt8}(undef, bytes(T)*N)

    pos = position(tf.io)
    seek(tf, t.data.position)
    read!(tf, rawdata)

    # if this datatype is comprised of multiple bytes and this file needs to be
    # bitswapped then we'll need to reverse the byte order inside each datatype
    # unit
    if tf.need_bswap && bytes(T) >= 2
        reverse!(rawdata)
        data = Array{T}(reverse(reinterpret(T, rawdata)))
    elseif T == String
        data = String(rawdata)
    elseif T == Any
        data = Array{Any}(rawdata)
    else
        data = Array{T}(reinterpret(T, rawdata))
    end

    if N == 1
        data = first(data)
    end
    seek(tf, pos)

    Tag(t.tag, data)
end

bytes(x::Type) = sizeof(x)
bytes(::Type{Any}) = 1
bytes(::Type{String}) = 1
bytes(::Type{RemoteData{O}}) where {O} = one(O)
bytes(::Type{<: AbstractVector{T}}) where {T} = bytes(T)

function Base.read(tf::TiffFile{O}, ::Type{Tag}) where O <: Unsigned
    tag = read(tf, UInt16)
    datatype = read(tf, UInt16)
    count = read(tf, O)
    data = Vector{UInt8}(undef, sizeof(O))
    read!(tf, data)

    T = Any
    if datatype in keys(tiff_to_julian)
        T = tiff_to_julian[datatype]
    end

    nbytes = bytes(T) * count
    if nbytes <= sizeof(O)
        if tf.need_bswap
            reverse!(view(data, 1:nbytes))
        end
        if T == String
            return Tag(tag, String(data))
        elseif T == Any
            return Tag(tag, Array{Any}(data))
        elseif count == 1
            return Tag(tag, first(reinterpret(T, data)))
        else
            return Tag(tag, Array(reinterpret(T, data)[1:Int(count)]))
        end
    else
        (tf.need_bswap) && reverse!(data)
        return Tag(tag, RemoteData(first(reinterpret(O, data)), T, count))
    end
end

_showdata(io::IO, t::Tag{RemoteData{O}}) where {O} = print(io, "REMOTE@$(t.data.position) $(t.data.datatype)[] len=$(t.data.count)")
_showdata(io::IO, t::Tag{<: AbstractString}) = print(io, "\"", first(t.data, 20), (length(t.data) > 20) ? "..." : "", "\"")
_showdata(io::IO, t::Tag{<: AbstractVector}) = print(io, "$(eltype(t.data))[", join(t.data[1:min(5, end)], ", "), (length(t.data) > 5) ? ", ..." : "", "]")
_showdata(io::IO, t::Tag) = print(io, t.data)

function Base.show(io::IO, t::Tag)
    print(io, "Tag(")
    try
        print(io, TiffTag(t.tag), ", ")
    catch
        print(io, "UNKNOWN($(Int(t.tag))), ")
    end
    if t.tag == Int(COMPRESSION)
        print(io, CompressionType(t.data))
    else
        _showdata(io, t)
    end
    print(io, ")")
end

"""
    write(tf, t)

Write tag `t` to the tiff file `tf`. Returns `true` if the tag data fit
entirely in the IFD space and was written to disk. Otherwise it returns false.
"""
function Base.write(tf::TiffFile{O}, t::Tag{T}) where {O <: Unsigned, T}
    # if the data are too large to fit then we'll need to skip writing this tag
    # for now until we know the length of the entire IFD
    if length(t)*bytes(T) > sizeof(O)
        _writeblank(tf)
        return false
    end

    # add NUL terminator to the end of Strings that don't have it already
    data = (T == String && !endswith(t.data, '\0')) ? t.data * "\0" : t.data

    write(tf, t.tag)
    write(tf, julian_to_tiff[eltype(t)])
    write(tf, O(length(t)))
    nbytes = write(tf.io, data)

    # write padding
    if nbytes < sizeof(O)
        write(tf, fill(0x00, sizeof(O) - nbytes))
    end
    true
end

function Base.write(tf::TiffFile{O}, t::Tag{RemoteData{O}}) where {O <: Unsigned}
    write(tf, t.tag)
    write(tf, julian_to_tiff[t.data.datatype])
    write(tf, t.data.count)
    write(tf, t.data.position)
    true
end


function Base.write(tf::TiffFile{O}, t::Tag, offset) where {O <: Unsigned}
    write(tf, Tag(t.tag, RemoteData(O(offset), eltype(t), O(length(t)))))
end

# Base.write(tf::TiffFile, t::Tag) = error("Tag offsets must agree with file offsets")

function _writeblank(tf::TiffFile{O}) where O
    write(tf, UInt32(0))
    write(tf, zero(O))
    write(tf, zero(O))
end

const tagfields = fieldnames(Tag)
function Base.:(==)(t1::Tag{O1}, t2::Tag{O2}) where {O1, O2}
    return O1 == O2 && getproperty.(Ref(t1), tagfields) == getproperty.(Ref(t2), tagfields)
end
