using Base: @propagate_inbounds

"""
    $(TYPEDEF)

The most common TIFF structure that associates an Image File Directory, aka
[`TiffImages.IFD`](@ref), with each XY image slice.

```jldoctest; setup = :(using TiffImages, ColorTypes)
julia> img = TiffImages.DenseTaggedImage(Gray.(zeros(UInt8, 10, 10)));

julia> size(img)
(10, 10)

julia> img.ifds
1-element Vector{TiffImages.IFD{UInt32}}:
 IFD, with tags:
	Tag(IMAGEWIDTH, 10)
	Tag(IMAGELENGTH, 10)
	Tag(BITSPERSAMPLE, 8)
	Tag(PHOTOMETRIC, 1)
	Tag(SAMPLESPERPIXEL, 1)
	Tag(SAMPLEFORMAT, 1)

julia> first(img.ifds)[TiffImages.XRESOLUTION] = 0x00000014//0x00000064 # write custom data
0x00000001//0x00000005

julia> TiffImages.save(mktemp()[2], img); # write to temp file
```

!!! note
    Currently, when writing custom info to tags, play attention to the types
    expected by other TIFF engines. For example,
    [`XRESOLUTION`](https://www.awaresystems.be/imaging/tiff/tifftags/xresolution.html)
    above expects a `rational` by default, which is equivalent to the Julian
    `Rational{UInt32}`

See also [`TiffImages.load`](@ref) and [`TiffImages.save`](@ref)
"""
struct DenseTaggedImage{T, N, O <: Unsigned, AA <: AbstractArray} <: AbstractDenseTIFF{T, N}
    data::AA
    ifds::Vector{IFD{O}}

    function DenseTaggedImage(data::AbstractArray{T, N}, ifds::Vector{IFD{O}}) where {T, N, O}
        if N == 3
            @assert size(data, 3) == length(ifds)
            newifds = _constructifd(data)
        elseif N == 2
            @assert length(ifds) == 1
            newifds = [_constructifd(data, O)]
        end
        new{T, N, O, typeof(data)}(data, map(x->merge(cleanup(x[1]), x[2]), zip(ifds, newifds)))
    end
end

function DenseTaggedImage(data::AbstractArray{T, 2}, ifd::IFD{O}) where {T, O}
    DenseTaggedImage(data, IFD{O}[ifd])
end

DenseTaggedImage(data::AbstractArray{T, 3}) where {T} = DenseTaggedImage(data, _constructifd(data))
DenseTaggedImage(data::AbstractArray{T, 3}, ::Type{O}) where {T, O} = DenseTaggedImage(data, _constructifd(data, O))
DenseTaggedImage(data::AbstractArray{T, 2}) where {T} = DenseTaggedImage(data, [_constructifd(data, UInt32)])
DenseTaggedImage(data::AbstractArray{T, 2}, ::Type{O}) where {T, O} = DenseTaggedImage(data, [_constructifd(data, UInt32)])

Base.size(t::DenseTaggedImage) = size(t.data)
Base.axes(t::DenseTaggedImage) = axes(t.data)

@propagate_inbounds Base.getindex(img::DenseTaggedImage, i...) = getindex(img.data, i...)
@propagate_inbounds Base.setindex!(img::DenseTaggedImage, i...) = setindex!(img.data, i...)
@propagate_inbounds function Base.getindex(img::DenseTaggedImage{T, 3}, i::Colon, j::Colon, k) where {T}
    DenseTaggedImage(getindex(img.data, i, j, k), img.ifds[k])
end

# Override the fallback convert to get better performance
# ImageIO requires this to get rid of the convert overhead
# Ref: https://github.com/JuliaIO/ImageIO.jl/pull/26
Base.convert(::Type{AA}, img::DenseTaggedImage{T,N,O,AA}) where {T,N,O,AA<:Array} = img.data

"""
    offset(img)

Returns the type of the TIFF file offset. For most TIFFs, it should be UInt32,
while for BigTIFFs it will be UInt64.
"""
offset(::DenseTaggedImage{T, N, O, AA}) where {T, N, O, AA} = O

function _constructifd(data::AbstractArray{T, 3}) where {T <: Colorant} 
    offset = UInt32
    # this is only a crude estimate for the amount information that we can store
    # in regular TIFF. The real value should take into account the size of the
    # header, the size of a minimal set of tags in each IFDs. 
    if sizeof(T) * length(data) >= typemax(offset)
        @info "Array too large to fit in standard TIFF container, switching to BigTIFF"
        offset = UInt64
    end
    _constructifd(data, offset)
end
"""
    _constructifd(data, offset)

Generate a IFD with the minimal set of tags to describe `data`.
"""
function _constructifd(data::AbstractArray{T, 3}, ::Type{O}) where {T <: Colorant, O <: Unsigned}
    ifds = IFD{O}[]

    for slice in axes(data, 3)
        push!(ifds, _constructifd(view(data, :, :, slice), O))
    end

    ifds
end

const cleanup_list = [
    EXTRASAMPLES,
    ROWSPERSTRIP,
    PLANARCONFIG,
    SAMPLEFORMAT
]

"""
    Creates a new IFD with a non-exhaustive list of problematic tags removed that 
will mess up the final tiff if they are included. These aren't merged away with the
default set created by `_constructifd`
"""
function cleanup(ifd::IFD{O}) where {O <: Unsigned}
    newifd = IFD(O, copy(ifd.tags))
    for tag in cleanup_list
        delete!(newifd, tag)
    end
    newifd
end

function _constructifd(data::AbstractArray{T, 2}, ::Type{O}) where {T <: Colorant, O <: Unsigned}
    ifd = IFD(O)

    ifd[IMAGEWIDTH] = UInt32(size(data, 2))
    ifd[IMAGELENGTH] = UInt32(size(data, 1))
    n_samples = samplesperpixel(data)
    ifd[BITSPERSAMPLE] = fill(UInt16(bitspersample(data)), n_samples)
    ifd[PHOTOMETRIC] = interpretation(data)
    ifd[SAMPLESPERPIXEL] = UInt16(n_samples)
    if !(T <: Gray{Bool}) # bilevel images don't have the sampleformat tag
        ifd[SAMPLEFORMAT] = fill(UInt16(sampleformat(data)), n_samples)
    end
    extra = extrasamples(data)
    if extra !== nothing
        ifd[EXTRASAMPLES] = extra
    end
    ifd
end

Base.write(io::IOStream, img::DenseTaggedImage) = write(getstream(format"TIFF", io, extract_filename(io)), img)

function _writeslice(pagecache, tf::TiffFile{O, S}, slice, ifd, prev_ifd_record) where {O, S}
    data_pos = position(tf.io) # start of data
    plain_data_view = reshape(PermutedDimsArray(slice, (2, 1)), :)
    pagecache .= reinterpret(UInt8, plain_data_view)
    write(tf, pagecache) # write data
    ifd_pos = position(tf.io)

    # update record of previous IFD to point to this new IFD
    seek(tf.io, prev_ifd_record)
    write(tf, O(ifd_pos))

    ifd[COMPRESSION] = COMPRESSION_NONE
    ifd[STRIPOFFSETS] = O(data_pos)
    ifd[STRIPBYTECOUNTS] = O(ifd_pos-data_pos)

    version = "$(parentmodule(IFD)::Module).jl v$PKGVERSION"
    if SOFTWARE in ifd
        ifd[SOFTWARE] = "$(ifd[SOFTWARE].data);$version"
    else
        ifd[SOFTWARE] = version
    end

    seek(tf.io, ifd_pos)
    prev_ifd_record = write(tf, ifd)
    seekend(tf.io)
    prev_ifd_record
end

function Base.write(io::Stream, img::DenseTaggedImage)
    O = offset(img)
    tf = TiffFile{O}(io)

    prev_ifd_record = write(tf) # record that will have be updated

    pagecache = Vector{UInt8}(undef, size(img.data, 2) * sizeof(eltype(img.data)) * size(img.data, 1))

    # For offseted arrays, `axes(img, 3) == 1:length(img.ifds)` does not hold in general
    for (idx, ifd) in zip(axes(img, 3), img.ifds)
        prev_ifd_record = _writeslice(pagecache, tf, view(img, :, :, idx), ifd, prev_ifd_record)
    end

    prev_ifd_record
end

"""
    save(io, data)

Write data to `io`, if data is a `DenseTaggedImage` then any custom tags are
also written to the file, otherwise a minimal set of tags are added to make the
data readable by other TIFF engines.
"""
save(io::IO, data::DenseTaggedImage) where {IO <: Union{IOStream, Stream}} = write(io, data)
save(io::IO, data) where {IO <: Union{IOStream, Stream}} = save(io, DenseTaggedImage(data))
function save(filepath::String, data)
    _safe_open(filepath, "w") do io
        save(getstream(format"TIFF", io, filepath), data)
    end
    nothing
end

Base.push!(A::DenseTaggedImage{T, N, O, AA}, data) where {T, N, O, AA} = error("push! is only supported for memory mapped images. See `LazyBufferedTIFF`.")
