struct Tag{O <: Unsigned}
    tag::UInt16
    datatype::DataType
    count::O
    data::Vector{UInt8}
    loaded::Bool
end

function load(tf::TiffFile{O}, t::Tag{O}) where {O}
    (t.loaded) && return t

    loc = first(reinterpret(O, getfield(t, :data)))

    data = Vector{UInt8}(undef, bytes(t.datatype)*t.count)

    pos = position(tf.io)
    seek(tf, loc)
    read!(tf, data)
    if tf.need_bswap
        reverse!(data)
    end
    seek(tf, pos)

    Tag(t.tag, t.datatype, t.count, data, true)
end

function Base.getproperty(t::Tag{O}, sym::Symbol) where {O}
    (sym != :data) && return getfield(t, sym)

    if !t.loaded
        error("This tag has remote data and it hasn't been loaded yet. Call `load!` first")
    end

    T = t.datatype 
    T = T == Any ? UInt8 : T

    data = getfield(t, sym)
    if T == UInt8
        converted = data
    elseif isbitstype(T)
        converted = reinterpret(t.datatype, data)
    elseif T == String
        converted = String(data)
    else
        error("Unexpected tag type")
    end

    converted
end

bytes(x::Type) = sizeof(x)
bytes(::Type{Any}) = 1
bytes(::Type{String}) = 1

function Base.read(tf::TiffFile, ::Type{Tag{O}}) where O <: Unsigned
    tag = read(tf, UInt16)
    datatype = read(tf, UInt16)
    count = read(tf, O)
    data = Vector{UInt8}(undef, sizeof(O))
    read!(tf, data)

    T = Any
    if datatype in keys(type_mapping)
        T = type_mapping[datatype]
    end

    nbytes = bytes(T) * count
    if nbytes <= sizeof(O)
        if tf.need_bswap
            reverse!(view(data, 1:nbytes))
        end
        Tag(tag, T, count, data, true)
    else
        (tf.need_bswap) && reverse!(data)
        Tag(tag, T, count, data, false)
    end
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
        print(CompressionType(first(t.data)))
    else
        if t.loaded
            print(first(t.data))
        else
            print("***")
        end
    end
    println(")")
end