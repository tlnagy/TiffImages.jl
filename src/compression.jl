"""
    read!(tf, arr, comp)

Read in an array `arr` from the [`TiffFile`](@ref) stream `tf` inflating the
data using compression method `comp`. `read!` will dispatch on the value of
compression and use the correct compression technique to read the data.
"""
Base.read!(tf::TiffFile, arr::AbstractArray, comp::CompressionType) = read!(tf, arr, Val(comp))

Base.read!(tf::TiffFile, arr::AbstractArray, ::Val{COMPRESSION_NONE}) = read!(tf, arr)

function Base.read!(tf::TiffFile, arr::AbstractArray{T, N}, ::Val{COMPRESSION_PACKBITS}) where {T, N}
    pos = 1
    nbit = Array{Int8}(undef, 1)
    nxt = Array{T}(undef, 1)
    while pos < length(arr)
        read!(tf, nbit)
        n = nbit[1]
        if 0 <= n <= 127
            read!(tf, view(arr, pos:pos+n))
            pos += n
        elseif -127 <= n <= -1
            read!(tf, nxt)
            arr[pos:(pos-n)] .= nxt[1]
            pos += -n
        end
        pos += 1
    end
end

"""
    get_inflator(x)

Given a `read!` signature, returns the compression technique implemented.

```jldoctest
julia> TiffImages.get_inflator(first(methods(read!, [TiffImages.TiffFile, AbstractArray, Val{TiffImages.COMPRESSION_NONE}], [TiffImages])).sig)
COMPRESSION_NONE::CompressionType = 1
```
"""
get_inflator(::Type{Tuple{typeof(read!), TiffFile, AbstractArray{T, N} where {T, N}, Val{C}}}) where C = C

# autogenerate nice error messages for all non-implemented inflation methods
implemented = map(x->get_inflator(x.sig), methods(read!, [TiffFile, AbstractArray, Val], ))
comps = Set(instances(CompressionType))
setdiff!(comps, implemented)

for comp in comps
    eval(quote
        Base.read!(tf::TiffFile, arr::AbstractArray, ::Val{$comp}) = error("Compression ", $comp, " is not implemented. Please open an issue against TiffImages.jl.")
    end)
end