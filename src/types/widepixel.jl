struct WidePixel{C <: Colorant, X <: Tuple}
    color::C
    extra::X
end

Base.zero(::WidePixel{C, X}) where {C, X} = WidePixel(zero(C), zero.(fieldtypes(X)))

function Base.show(io::IO, x::WidePixel{C,X}) where {C, X}
    print(io, "WidePixel($(x.color))")
end