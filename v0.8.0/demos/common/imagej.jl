using Images, TiffImages, Unitful
img0 = zeros(Gray{N0f8}, 10, 10, 12) #example image
img = TiffImages.DenseTaggedImage(img0)

!isdefined(Main, :ifds) && (ifds = x-> x.ifds) #hide

resunit = UInt8(3) # 1: No absolute unit of measurement, 2: Inch, 3: Centimeter
[ifd[TiffImages.RESOLUTIONUNIT] = resunit for ifd in ifds(img)];

resxy = Rational{UInt32}(round(1u"cm"/0.653u"μm", digits = 3)) # Type must be rational. In this example, the pixel size is 0.653 μm x 0.653 μm.
[ifd[TiffImages.XRESOLUTION] = resxy for ifd in ifds(img)]
[ifd[TiffImages.YRESOLUTION] = resxy for ifd in ifds(img)]
first(ifds(img))

first(ifds(img))[TiffImages.IMAGEDESCRIPTION] = # only in the first IFD
"ImageJ=1.51d
images=12
frames=3
slices=4
hyperstack=true
spacing=5.0
unit=um
finterval=0.2
axes=TZYX"

first(ifds(img))

TiffImages.save("imagej.tiff", img)

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
