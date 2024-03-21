abstract type AbstractTIFF{T, N} <: AbstractArray{T, N} end

abstract type AbstractDenseTIFF{T, N} <: AbstractTIFF{T, N} end

abstract type AbstractStridedTIFF{T, N} <: AbstractTIFF{T, N} end

function Base.getproperty(img::T, sym::Symbol) where {T <: AbstractTIFF}
    if sym === :ifds
        Base.depwarn("Directly accessing the ifds property is deprecated" * 
        " and will be removed in TiffImages v0.7.0+. Please use `ifds(img)` instead.",
        :AbstractTIFF)
    end
    getfield(img, sym)
end

"""
    ifds(img)

Get the Image File Directories of `img`, see [`TiffImages.IFD`] for details.
Returns a single IFD for a 2D TIFF. Otherwise, returns a list of IFDs with a
length equal to the third dimension of a 3D TIFF.
```
"""
ifds(img::I) where {I <: AbstractTIFF{T, 2} where {T}} = first(getfield(img, :ifds))
ifds(img::I) where {I <: AbstractTIFF} = getfield(img, :ifds)

interpretation(img::AbstractArray) = interpretation(eltype(img))
interpretation(::Type{T}) where {T <: Gray} = PHOTOMETRIC_MINISBLACK
interpretation(::Type{T}) where {T <: AbstractRGB} = PHOTOMETRIC_RGB
interpretation(::Type{<: TransparentColor{C, T, N}}) where {C, T, N} = interpretation(C)

samplesperpixel(img::AbstractArray) = samplesperpixel(eltype(img))
samplesperpixel(::Type{<: Colorant{T, N}}) where {T, N} = N

bitspersample(img::AbstractArray) = bitspersample(eltype(img))
bitspersample(::Type{<: Colorant{T, N}}) where {T, N} = sizeof(T) * 8
bitspersample(::Type{<: Colorant{<: FixedPoint{T, S}, N}}) where {T, S, N} = S

sampleformat(img::AbstractArray) = sampleformat(eltype(img))
sampleformat(::Type{<: Colorant{T, N}}) where {T <: AbstractFloat, N} = SAMPLEFORMAT_IEEEFP
sampleformat(::Type{<: Colorant{<: FixedPoint{T, S}, N}}) where {T <: Unsigned, N, S} = SAMPLEFORMAT_UINT
sampleformat(::Type{<: Colorant{<: FixedPoint{T, S}, N}}) where {T <: Signed, N, S} = SAMPLEFORMAT_INT
sampleformat(::Type{<: Colorant{Complex{T}, N}}) where {T <: AbstractFloat, N} = SAMPLEFORMAT_COMPLEXIEEEFP
sampleformat(::Type{<: Colorant{Complex{T}, N}}) where {T <: Signed, N} = SAMPLEFORMAT_COMPLEXINT

extrasamples(img::AbstractArray) = extrasamples(eltype(img))
extrasamples(img::Type) = nothing
extrasamples(img::Type{<: TransparentColor}) = 1