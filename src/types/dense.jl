struct DenseTaggedImage{T, N, O} <: AbstractTIFF{T, N} where {O <: Unsigned}
    data::AbstractArray{T, N}

    ifds::Vector{IFD{O}}
end

function DenseTaggedImage(data::AbstractArray{T, 2}, ifd::IFD{O}) where {T, O}
    DenseTaggedImage(data, IFD{O}[ifd])
end

Base.size(t::DenseTaggedImage) = size(t.data)

Base.getindex(img::DenseTaggedImage, i...) = getindex(img.data, i...)
Base.getindex(img::DenseTaggedImage{T, 3}, i::Int, j::Int, k::Int) where {T} = getindex(img.data, i, j, k)

function Base.getindex(img::DenseTaggedImage{T, 3}, i::Colon, j::Colon, k) where {T}
    DenseTaggedImage(getindex(img.data, i, j, k), img.ifds[k])
end


