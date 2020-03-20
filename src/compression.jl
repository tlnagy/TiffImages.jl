"""
    read!(tf, arr, comp)

Read in an array `arr` from the [`TiffFile`](@ref) stream `tf` inflating the
data using compression method `comp`. `read!` will dispatch on the value of
compression and use the correct compression technique to read the data.
"""
Base.read!(tf::TiffFile, arr::AbstractArray, comp::CompressionType) = read!(tf, arr, Val(comp))

Base.read!(tf::TiffFile, arr::AbstractArray, ::Val{COMPRESSION_NONE}) = read!(tf, arr)

function Base.read!(tf::TiffFile, arr::AbstractArray, ::Val{COMPRESSION_PACKBITS})
    pos = 1
    nbit = Array{Int8}(undef, 1)
    nxt = Array{UInt8}(undef, 1)
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