abstract type AbstractTIFF{T, N} <: AbstractArray{T, N} end

abstract type AbstractDenseTIFF{T, N} <: AbstractTIFF{T, N} end

abstract type AbstractStridedTIFF{T, N} <: AbstractTIFF{T, N} end