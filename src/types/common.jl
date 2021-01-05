abstract type AbstractTIFF{T, N} <: AbstractArray{T, N} end

abstract type AbstractDenseTIFF{T, N} <: AbstractTIFF{T, N} end

abstract type AbstractStridedTIFF{T, N} <: AbstractTIFF{T, N} end

interpretation(img::AbstractArray) = interpretation(eltype(img))
interpretation(::Type{T}) where {T <: Gray} = PHOTOMETRIC_MINISBLACK
interpretation(::Type{T}) where {T <: AbstractRGB} = PHOTOMETRIC_RGB
interpretation(::Type{<: TransparentColor{C, T, N}}) where {C, T, N} = interpretation(C)

samplesperpixel(img::AbstractArray) = samplesperpixel(eltype(img))
samplesperpixel(::Type{<: Colorant{T, N}}) where {T, N} = N

bitspersample(img::AbstractArray) = bitspersample(eltype(img))
bitspersample(::Type{<: Colorant{T, N}}) where {T, N} = sizeof(T)*8

sampleformat(img::AbstractArray) = sampleformat(eltype(img))
sampleformat(::Type{<: Colorant{T, N}}) where {T <: AbstractFloat, N} = SAMPLEFORMAT_IEEEFP
sampleformat(::Type{<: Colorant{<: FixedPoint{T, S}, N}}) where {T <: Unsigned, N, S} = SAMPLEFORMAT_UINT
sampleformat(::Type{<: Colorant{<: FixedPoint{T, S}, N}}) where {T <: Signed, N, S} = SAMPLEFORMAT_INT
sampleformat(::Type{<: Colorant{Complex{T}, N}}) where {T <: AbstractFloat, N} = SAMPLEFORMAT_COMPLEXIEEEFP
sampleformat(::Type{<: Colorant{Complex{T}, N}}) where {T <: Signed, N} = SAMPLEFORMAT_COMPLEXINT

extrasamples(img::AbstractArray) = extrasamples(eltype(img))
extrasamples(img::Type) = nothing
extrasamples(img::Type{<: TransparentColor}) = 1