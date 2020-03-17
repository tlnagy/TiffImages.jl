struct StridedTaggedImage{T, O} <: AbstractTIFF{T, 1} where {O <: Unsigned}
    data::Vector{AbstractArray{T, 2}}

    ifds::Vector{IFD{O}}
end

function StridedTaggedImage(data::AbstractArray{T, 2}, ifd::IFD{O}) where {T, O}
    StridedTaggedImage([data], IFD{O}[ifd])
end

Base.size(t::StridedTaggedImage) = length(t.data)
Base.getindex(img::StridedTaggedImage, i) = getindex(img.data, i)



