struct Tag{O <: Unsigned}
    tag::UInt16
    datatype::DataType
    count::O
    data::O
end

function Base.show(io::IO, t::Tag{O}) where {O}
    print("TIFF.Tag{$O}(")
    try
        print(TiffTag(t.tag), ", ")
    catch
        print("UNKNOWN($(Int(t.tag))), ")
    end
    print(t.datatype, ", ")
    print(Int(t.count), ", ")
    if t.tag == Int(COMPRESSION)
        print(CompressionType(t.data))
    else
        print(Int(t.data))
    end
    (isremote(t)) && print("*")
    print(")")
end

isremote(t::Tag{O}) where {O} = bytes(t.datatype) * t.count > bytes(O)

function get(tf::TiffFile, t::Tag)
    T = t.datatype
    (T == String || T == Any) && (T = UInt8)

    sz = sizeof(T)
    curr_pos = position(tf.io)

    data = Array{T}(undef, t.count)
    if sz * t.count <= 4
        io = IOBuffer()
        write(io, t.data)
        seekstart(io)
    else
        data = Array{T}(undef, t.count)
        io = tf
        seek(tf, t.data)
    end
    read!(io, data)

    if t.datatype == String
        data = String(data)
    end

    # return to original position
    seek(tf, curr_pos)
    data
end

bytes(x::Type) = sizeof(x)
bytes(::Type{Any}) = 1
bytes(::Type{String}) = 1

function Base.read(tf::TiffFile, ::Type{Tag{O}}) where O <: Unsigned
    tag = read(tf, UInt16)
    datatype = read(tf, UInt16)
    count = read(tf, O)
    if !(datatype in keys(type_mapping))
        data = read(tf, O)
        return Tag(tag, Any, count, data)
    end
    T = type_mapping[datatype]
    R = ((T == String) | (T == Any)) ? UInt8 : T # type to read in as

    # we need to check if the type has any padding because we don't want to
    # include the padding when doing the bswap operation
    padding = max(bytes(O) - bytes(T) * max(count, 1), 0)
    (padding == 0) && (R = O)

    data = read(tf, R)

    # if there is padding, cast it as type O so that it agrees with all other
    # tags and skip to the end of this tag block
    if padding > 0
        data = O(data)
        seek(tf.io, position(tf.io)+padding)
    end
    Tag(tag, T, count, data)
end
