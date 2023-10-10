istiled(ifd::IFD) = TILEWIDTH in ifd
tilecols(ifd::IFD) = Int(ifd[TILEWIDTH].data)::Int
tilerows(ifd::IFD) = Int(ifd[TILELENGTH].data)::Int
nrows(ifd::IFD) = Int(ifd[IMAGELENGTH].data)::Int
ncols(ifd::IFD) = Int(ifd[IMAGEWIDTH].data)::Int
ntiles(ifd) = Int(length(ifd[TILEOFFSETS]))::Int
nsamples(ifd::IFD) = Int(getdata(ifd, SAMPLESPERPIXEL, 1))
predictor(ifd::IFD) = Int(getdata(ifd, PREDICTOR, 0))

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

_mappedtype(::Type{T}) where {T} = T
_mappedtype(::Type{T}) where {T <: Unsigned} = Normed{T, sizeof(T) * 8}
_mappedtype(::Type{T}) where {T <: Signed}   = Fixed{T, sizeof(T) * 8 - 1}

function rawtype(ifd::IFD)
    samplesperpixel = nsamples(ifd)
    bitsperpixel = ifd[BITSPERSAMPLE].data
    sampleformats = fill(UInt16(0x01), samplesperpixel)
    if SAMPLEFORMAT in ifd
        sampleformats = ifd[SAMPLEFORMAT].data
    end
    rawtype_mapping[SampleFormats(first(sampleformats)), first(bitsperpixel)]
end

"""
    $(SIGNATURES)

Allocate a cache for this IFD with correct type and size.
"""
function getcache(ifd::IFD)
    T = rawtype(ifd)
    if T === Bool
        return BitArray(undef, ncols(ifd), nrows(ifd))
    end
    colortype, extras = interpretation(ifd)
    if istiled(ifd)
        tile_width = tilecols(ifd)
        tile_height = tilerows(ifd)
        return Array{colortype{_mappedtype(T)}}(undef, cld(ncols(ifd), tile_width) * tile_width, cld(nrows(ifd), tile_height) * tile_height)
    else
        return Array{colortype{_mappedtype(T)}}(undef, ncols(ifd), nrows(ifd))
    end
end
