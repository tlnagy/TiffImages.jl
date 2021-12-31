# # Memory-mapping TIFFs

# If you're running into memory-limitations when working with large datasets,
# you can memory-map the file so that it looks and behaves as if it were loaded,
# but it instead lazily loads data only when needed.

#md # ```@contents
#md # Pages = ["mmap.md"]
#md # Depth = 5
#md # ```

get_example(name) = download("https://github.com/tlnagy/exampletiffs/blob/master/$name?raw=true") #hide
filepath = get_example("mri.tif");                                                                #hide

# ### Memory-mapped loading

# Loading is very similar to [Reading TIFFs](@ref), except with the addition of
# the `mmap=true` flag. Here, we're loading `mri.tif` from the
# [`tlnagy/exampletiffs`](https://github.com/tlnagy/exampletiffs) repo

using TiffImages
img = TiffImages.load(filepath; mmap=true);

# The memory-mapped img will behave much the same as a normal eagerly loaded
# image:

size(img)

# Display the 2nd slice

img[:, :, 2] 

# Currently, TiffImages does not support inplace mutating operations on
# memory-mapped files. That is, using `setindex!` and friends will throw an
# error.

#img[:, :, 2] .= 0.0 # throws an error

# #### Lazy operations

# One of the primary benefits of memory-mapping is that it's lazy, that is,
# we're avoiding doing any unnecessary work. I recommend using `MappedArrays` to
# continue the "laziness" of operations to avoid any extra work.

# !!! warning
#     `TiffImages` caches each slice when you access it so operations that
#     involve slices will be fast, i.e. operations along the 1st and 2nd
#     dimensions of an image are quick, operations along the 3rd dimension are
#     slow.
# 
#     For example, `img[:, :, 1]` is fast. `img[1, 1, :]` will be slower since 
#     in the latter case, each whole slice has to be loaded to only grab a single 
#     element

using Colors
using MappedArrays

eltype(img)

# We can lazily convert our data for only the slices we end up actually
# displaying

gray_img = of_eltype(Gray, img);

# Lets lazily load a slice from disk and then convert only that one to gray

slice = gray_img[:, :, 1] 

# We can check to make sure its `eltype` is correct:

eltype(slice)

# #### Example: Maximum intensity projection

# It's pretty straigtforward to do a max-intensity projection:

dropdims(maximum(gray_img, dims=3), dims=3)


# ### Memory-mapped writing

# `TiffImages` also supports writing to a memory-mapped file via an append
# operation. As with most arrays, you need to provide an element type and a
# filepath, but we'll use the [`memmap`](@ref) function in place of `load`

using TiffImages #hide
#--------------
using Images # reexports Gray and N0f8 
img2 = memmap(Gray{N0f8}, "test.tif")

# !!! note
#     For data-integrity reasons, `TiffImages` will not allow you to append to
#     an pre-existing file and will throw an error if a file exists at the
#     filepath that you provide.

# Say you have the following data:

slice = rand(Gray{N0f8}, 256, 256)

# You can then push new data to the `img2` object and it will eagerly write that
# data to disk.

push!(img2, slice)

# The first slice sets the XY dimensions of the TIFF and subsequent slices must
# have the same dimensions as the first.

push!(img2, rand(Gray{N0f8}, 256, 256))

# The memory-mapped object also behaves like an array and supports most array
# operations (other than inplace mutating ones like `setindex!`)

size(img2)

# To read a slice that you just wrote:

img2[:, :, 2]

# #### XL files

# If you're going to be writing lots of data to disk (4GB+) then it can be
# helpful to set the `bigtiff` flag to true so that `TiffImages` can use 64-bit
# offsets. You'll see that the addressable space sky rockets:

img3 = memmap(Gray{N0f16}, "test.btif"; bigtiff=true)