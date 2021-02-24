using TiffImages
using TiffImages.ColorTypes: Gray, RGB
using TiffImages.FixedPointNumbers: N0f8

fpath = "test.tiff"
for t in [N0f8, Float64]
    for typ in [Gray, RGB]
        img = rand(typ{t}, 2, 2)
        TiffImages.save(fpath, img)
        img2 = TiffImages.load(fpath)
    end
end

include(joinpath(dirname(@__DIR__), "test", "runtests.jl"))
