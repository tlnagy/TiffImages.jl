abstract type AbstractTIFF{T, N} <: AbstractArray{T, N} end

struct TaggedImage{T, N, O} <: AbstractTIFF{T, N} where {O <: Unsigned}
    data::AbstractArray{T, N}

    ifds::Vector{IFD{O}}
end

function TaggedImage(data::AbstractArray{T, 2}, ifd::IFD{O}) where {T, O}
    TaggedImage(data, IFD{O}[ifd])
end

Base.size(t::TaggedImage) = size(t.data)

function Base.getindex(img::TaggedImage{T, 3}, i::Colon, j::Colon, k) where {T}
    TaggedImage(getindex(img.data, i, j, k), img.ifds[k])
end

Base.getindex(img::TaggedImage, i...) = getindex(img.data, i...)

Base.getindex(img::TaggedImage{T, 3}, i::Int, j::Int, k::Int) where {T} = getindex(img.data, i, j, k)

function load(filepath)
    tf = TiffFile(open(filepath))

    ifds = collect(ifd for ifd in tf)

    head = first(ifds)

    nrows = get(tf, head[IMAGEWIDTH])[1]
    ncols = get(tf, head[IMAGELENGTH])[1]
    nplanes = length(ifds)

    data = Array{Gray{N0f16}}(undef, nrows, ncols, nplanes)
    for (idx, ifd) in enumerate(ifds)
        data[:, :, idx] .= read(tf, ifd)
    end

    close(tf.io)
    TaggedImage(data, ifds)
end