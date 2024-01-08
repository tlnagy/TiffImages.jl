struct WidePixel{C <: Colorant, X <: Tuple}
    color::C
    extra::X
end

WidePixel{C, X}(x::Tuple) where {C <: Colorant, X} = WidePixel(C(x[1:N]...), x[N+1:end])
WidePixel{C, X}(x...) where {C, X} = C(x...)

Base.zero(::WidePixel{C, X}) where {C, X} = WidePixel(zero(C), zero.(fieldtypes(X)))

function Base.show(io::IO, x::WidePixel{C,X}) where {C, X}
    print(io, "WidePixel($(x.color))")
end