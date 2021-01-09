# # Reading TIFFs

# Loading most TIFFs should just work, see [Writing TIFFs](@ref) for more
# advanced manipulation of TIFF objects. But we'll quickly run through a common
# use cases.

#md # ```@contents
#md # Pages = ["reading.md"]
#md # Depth = 5
#md # ```

get_example(name) = download("https://github.com/tlnagy/exampletiffs/blob/master/$name?raw=true") #hide
filepath = get_example("spring.tif")                                                              #hide

# ### Basic loading

# At it's most basic, we can just point `TiffImages.jl` to the filepath of an
# image and it will attempt to load it. Here, we're loading `spring.tif` from
# the [`tlnagy/exampletiffs`](https://github.com/tlnagy/exampletiffs) repo

using TiffImages
img = TiffImages.load(filepath)

# If you're a graphical environment, you can load the `Images.jl` repo to get
# a nice graphical representation of your image. If you're in the REPL, I highly
# recommend the `ImageInTerminal.jl` package for some visual feedback.

# Continuing on, `img` here behaves exactly as you would expect a Julian array
# to despite the funky type signature

typeof(img)

# Everything should behave as expected

eltype(img)
#---------

# Accessing and setting data should work as expected
img[160:180, 50]
#---------
img[160:180, 50] .= 1.0
img


# ### Memory-mapped files

# `TiffImages.jl` also supports memory-mapping so that you can load images that
# are larger than the available memory.

img = TiffImages.load(filepath, mmap=true)
img[:, :, 1]

# Naturally, this only really makes sense for large images, not the single pane
# image here. Currently, memory-mapped files are readonly so trying to set a
# value will throw an error

# ```julia
# img[1, 1, 1] = 0 # this won't work
# ```