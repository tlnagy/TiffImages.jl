using Base: @propagate_inbounds

struct DenseTaggedImage{T, N, O <: Unsigned,AA <: AbstractArray} <: AbstractDenseTIFF{T, N}
    data::AA
    ifds::Vector{IFD{O}}

    function DenseTaggedImage(data::AbstractArray{T, N}, ifds::Vector{IFD{O}}) where {T, N, O}
        if N == 3
            @assert size(data, 3) == length(ifds)
        elseif N == 2
            @assert length(ifds) == 1
        end
        new{T, N, O, typeof(data)}(data, ifds)
    end
end

function DenseTaggedImage(data::AbstractArray{T, 2}, ifd::IFD{O}) where {T, O}
    DenseTaggedImage{T, 2}(data, IFD{O}[ifd])
end

Base.size(t::DenseTaggedImage) = size(t.data)

@propagate_inbounds Base.getindex(img::DenseTaggedImage{T, N}, i::Vararg{Int, N}) where {T, N} = img.data[i...]
@propagate_inbounds Base.getindex(img::DenseTaggedImage, i...) = getindex(img.data, i...)
@propagate_inbounds Base.getindex(img::DenseTaggedImage{T, 3}, i::Int, j::Int, k::Int) where {T} = getindex(img.data, i, j, k)

Base.setindex!(img::DenseTaggedImage, i...) = setindex!(img.data, i...)

function Base.getindex(img::DenseTaggedImage{T, 3}, i::Colon, j::Colon, k) where {T}
    DenseTaggedImage(getindex(img.data, i, j, k), img.ifds[k])
end


