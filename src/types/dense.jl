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
    DenseTaggedImage(data, IFD{O}[ifd])
end

DenseTaggedImage(data::AbstractArray{T, 3}) where {T} = DenseTaggedImage(data, _constructifd(data))
DenseTaggedImage(data::AbstractArray{T, 2}) where {T} = DenseTaggedImage(data, [_constructifd(data, UInt32)])

Base.size(t::DenseTaggedImage) = size(t.data)

@propagate_inbounds Base.getindex(img::DenseTaggedImage{T, N}, i::Vararg{Int, N}) where {T, N} = img.data[i...]
@propagate_inbounds Base.getindex(img::DenseTaggedImage, i...) = getindex(img.data, i...)
@propagate_inbounds Base.getindex(img::DenseTaggedImage{T, 3}, i::Int, j::Int, k::Int) where {T} = getindex(img.data, i, j, k)

Base.setindex!(img::DenseTaggedImage, i...) = setindex!(img.data, i...)

function Base.getindex(img::DenseTaggedImage{T, 3}, i::Colon, j::Colon, k) where {T}
    DenseTaggedImage(getindex(img.data, i, j, k), img.ifds[k])
end

"""
    offset(img)

Returns the type of the TIFF file offset. For most TIFFs, it should be UInt32,
while for BigTIFFs it will be UInt64.
"""
offset(::DenseTaggedImage{T, N, O, AA}) where {T, N, O, AA} = O

function _constructifd(data::AbstractArray{T, 3}) where {T <: Colorant}
    offset = UInt32
    if sizeof(T) * length(data) >= 3.8*10^9 
        @info "Array too large to fit in standard TIFF container, switching to BigTIFF"
        offset = UInt64
    end

    ifds = IFD{offset}[]

    for slice in 1:size(data, 3)
        push!(ifds, _constructifd(view(data, :, :, slice), offset))
    end

    ifds
end

function _constructifd(data::AbstractArray{T, 2}, ::Type{O}) where {T <: Colorant, O <: Unsigned}
    ifd = IFD(O)

    ifd[IMAGEWIDTH] = UInt32(size(data, 2))
    ifd[IMAGELENGTH] = UInt32(size(data, 1))
    n_samples = samplesperpixel(data)
    ifd[BITSPERSAMPLE] = fill(UInt16(bitspersample(data)), n_samples)
    ifd[PHOTOMETRIC] = interpretation(data)
    ifd[SAMPLESPERPIXEL] = UInt16(n_samples)
    ifd[SAMPLEFORMAT] = fill(UInt16(sampleformat(data)), n_samples)
    ifd
end

Base.write(io::IOStream, img::DenseTaggedImage) = write(Stream(format"TIFF", io, extract_filename(io)), img)

function Base.write(io::Stream, img::DenseTaggedImage)
    O = offset(img)
    tf = TiffFile(O)
    tf.io = io

    prev_ifd_record = write(tf) # record that will have be updated

    for (idx, ifd) in enumerate(img.ifds)
        data_pos = position(tf.io) # start of data

        write(tf, reinterpret(UInt8, permutedims(view(img.data, :, :, idx), [2, 1]))) # write data
        ifd_pos = position(tf.io)

        # update record of previous IFD to point to this new IFD
        seek(tf.io, prev_ifd_record) 
        write(tf, O(ifd_pos))

        ifd = first(img.ifds)
        ifd[COMPRESSION] = COMPRESSION_NONE
        ifd[STRIPOFFSETS] = O(data_pos)
        ifd[STRIPBYTECOUNTS] = O(ifd_pos-data_pos)
        ifd[SOFTWARE] = "$(parentmodule(IFD)).jl v$PKGVERSION"
        sort!(ifd.tags)

        seek(tf.io, ifd_pos)
        prev_ifd_record = write(tf, ifd)
        seekend(tf.io)
    end
end