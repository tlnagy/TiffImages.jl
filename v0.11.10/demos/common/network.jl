using TiffImages, Downloads, FileIO

function load_tiff_without_saving(url)
  buffer = IOBuffer()
  Downloads.download(url, buffer)
  bufstream = TiffImages.getstream(format"TIFF", buffer)
  TiffImages.load(read(bufstream, TiffFile))
end

coffeepath = "https://github.com/tlnagy/exampletiffs/raw/11516d288c4b03a258aa3027705b0e9d2ce2b5de/coffee.tif"
coffeeimg = load_tiff_without_saving(coffeepath)

save("assets/coffee.png", collect(coffeeimg[:, 70:470])) #hide
nothing #hide

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
