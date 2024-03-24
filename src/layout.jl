istiled(ifd::IFD) = TILEWIDTH in ifd
isplanar(ifd::IFD) = Int(getdata(ifd, PLANARCONFIG, 1)) == 2
tilecols(ifd::IFD) = Int(ifd[TILEWIDTH].data)::Int
tilerows(ifd::IFD) = Int(ifd[TILELENGTH].data)::Int
nrows(ifd::IFD) = Int(ifd[IMAGELENGTH].data)::Int
ncols(ifd::IFD) = Int(ifd[IMAGEWIDTH].data)::Int
nsamples(ifd::IFD) = Int(getdata(ifd, SAMPLESPERPIXEL, 1))
predictor(ifd::IFD) = Int(getdata(ifd, PREDICTOR, 0))
bitspersample(ifd::IFD) = Int(first(ifd[BITSPERSAMPLE].data))::Int
ispalette(ifd::IFD) = Int(getdata(ifd, PHOTOMETRIC, 0)) == 3
compression(ifd::IFD) = getdata(CompressionType, ifd, COMPRESSION, COMPRESSION_NONE)

is_irregular_bps(ifd::IFD) = bitspersample(ifd) != sizeof(rawtype(ifd)) * 8
is_complicated(ifd::IFD) = !iscontiguous(ifd) || compression(ifd) != COMPRESSION_NONE || is_irregular_bps(ifd) == true || predictor(ifd) > 1

"""
    interpretation(ifd)

For a given IFD, determine the proper colorimetric interpretation of the data.
It returns subtypes of `Colorant` depending on the values of the tiff tags and
whether there are extrasamples it doesn't know how to deal with.
"""
function interpretation(ifd::IFD)
    interp = PhotometricInterpretations(ifd[PHOTOMETRIC].data)
    extras = EXTRASAMPLE_UNSPECIFIED
    if EXTRASAMPLES in ifd
        try
            extras = ExtraSamples(ifd[EXTRASAMPLES].data)
        catch
            extras = EXTRASAMPLE_ASSOCALPHA
        end
    end
    interpretation(interp, extras, nsamples(ifd))
end

# dummy color type for palette colored images to dispatch on
struct Palette{T} <: Colorant{T, 1}
    i::T
end
Base.reinterpret(::Type{Palette{T}}, arr::A) where {T, N, S, A <: AbstractArray{S, N}} = arr

interpretation(p::PhotometricInterpretations) = interpretation(Val(p))
interpretation(::Val{PHOTOMETRIC_RGB}) = RGB
interpretation(::Val{PHOTOMETRIC_MINISBLACK}) = Gray
interpretation(::Val{PHOTOMETRIC_PALETTE}) = Palette
interpretation(::Val{PHOTOMETRIC_YCBCR}) = YCbCr
interpretation(::Val{PHOTOMETRIC_CIELAB}) = Lab

function interpretation(p::PhotometricInterpretations, extrasamples::ExtraSamples, samplesperpixel::Int)
    interp = interpretation(p)::Type{<:Colorant}
    len = length(interp)::Int
    if len + 1 == samplesperpixel
        return interpretation(p, extrasamples, Val(samplesperpixel))
    elseif len == samplesperpixel
        return interp, false
    elseif len < samplesperpixel
        return interp, true
    else
        error("TIFF file says it contains $interp values, but only has $samplesperpixel samples per pixel instead of the minimum required $len")
    end
end
_pad(::Type{RGB}) = RGBX
_pad(::Type{T}) where {T} = T

interpretation(p::PhotometricInterpretations, extrasamples::ExtraSamples, nsamples::Val) = interpretation(p, Val(extrasamples), nsamples)
interpretation(p::PhotometricInterpretations, ::Val{EXTRASAMPLE_UNSPECIFIED}, @nospecialize(::Val)) = interpretation(p), true
interpretation(p::PhotometricInterpretations, ::Val{EXTRASAMPLE_UNSPECIFIED}, ::Val{4}) = _pad(interpretation(p)), false
interpretation(p::PhotometricInterpretations, ::Val{EXTRASAMPLE_ASSOCALPHA}, @nospecialize(::Val)) = coloralpha(interpretation(p)), false
interpretation(p::PhotometricInterpretations, ::Val{EXTRASAMPLE_UNASSALPHA}, nsamples::Val) = interpretation(p, Val(EXTRASAMPLE_ASSOCALPHA), nsamples)

_mappedtype(::Type{T}, bps) where {T} = T
_mappedtype(::Type{T}, bps) where {T <: Unsigned} = Normed{T, bps}
_mappedtype(::Type{T}, bps) where {T <: Signed}   = Fixed{T, bps - 1}

function rawtype(ifd::IFD)
    samplesperpixel = nsamples(ifd)
    bitsperpixel = bitspersample(ifd)
    sampleformats = fill(UInt16(0x01), samplesperpixel)
    if SAMPLEFORMAT in ifd
        sampleformats = ifd[SAMPLEFORMAT].data
    end

    format = SampleFormats(first(sampleformats))
    n = first(bitsperpixel)

    n < 1 || n > 64 && error("unsupported bit depth ($n)")

    if format == SAMPLEFORMAT_IEEEFP
        if n == 16
            rtype = Float16
        elseif n == 32
            rtype = Float32
        elseif n == 64
            rtype = Float64
        else
            error("unsupported sample format")
        end
    elseif format == SAMPLEFORMAT_UINT || format == SAMPLEFORMAT_INT
        m = trailing_zeros(nextpow(2, n))
        if m <= 3
            rtype = format == SAMPLEFORMAT_UINT ? UInt8 : Int8
        elseif m == 4
            rtype = format == SAMPLEFORMAT_UINT ? UInt16 : Int16
        elseif m == 5
            rtype = format == SAMPLEFORMAT_UINT ? UInt32 : Int32
        elseif m == 6
            rtype = format == SAMPLEFORMAT_UINT ? UInt64 : Int64
        else
            error("unsupported sample format")
        end
    else
        error("unsupported sample format")
    end

    @debug "raw type for ($format, $n) is $rtype"

    rtype
end

"""
    $(SIGNATURES)

Allocate a cache for this IFD with correct type and size.
"""
function getcache(ifd::IFD)
    T = rawtype(ifd)
    colortype, extras = interpretation(ifd)
    bps = bitspersample(ifd)
    if istiled(ifd)
        tile_width = tilecols(ifd)
        tile_height = tilerows(ifd)
        return Array{colortype{_mappedtype(T, bps)}}(undef, cld(ncols(ifd), tile_width) * tile_width, cld(nrows(ifd), tile_height) * tile_height)
    else
        return Array{colortype{_mappedtype(T, bps)}}(undef, ncols(ifd), nrows(ifd))
    end
end

function uncompressed_size(ifd::IFD, columns::Int, rows::Int)
    bps = bitspersample(ifd)
    # each row is encoded separately
    cld(columns * bps, 8) * rows
end
