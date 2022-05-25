# # Lazy TIFFs

# If you're running into memory-limitations when working with large datasets,
# you can lazy-load or memory-map the file so that it looks and behaves as if it were loaded,
# but it instead loads data only when needed.

#md # ```@contents
#md # Pages = ["mmap_lazyio.md"]
#md # Depth = 5
#md # ```

get_example(name) = download("https://github.com/tlnagy/exampletiffs/blob/master/$name?raw=true") #hide
filepath = get_example("mri.tif");                                                                #hide

# ### Memory-mapping and lazy loading

# Loading is very similar to [Reading TIFFs](@ref), except with the addition of
# the `mmap=true` or `lazyio=true` flag. Here, we're loading `mri.tif` from the
# [`tlnagy/exampletiffs`](https://github.com/tlnagy/exampletiffs) repo

# `mmap=true` yields good indexing performance in a wider array of circumstances
# than `lazyio=true`, but `mmap` cannot handle compressed files or ones where data
# are stored in [strips](https://en.wikipedia.org/wiki/TIFF#Overview).
# Since this is a compressed TIFF, here we use `lazyio`:

using TiffImages
img = TiffImages.load(filepath; lazyio=true);

# The lazily-loaded img will behave much the same as a normal eagerly loaded
# image:

size(img)

# Display the 2nd slice

img[:, :, 2]

# Currently, TiffImages does not support inplace mutating operations on `lazyio`
# images: that is, using `setindex!` and friends will throw an error.

#img[:, :, 2] .= 0.0 # throws an error

# However, for files that can be supported by `mmap=true`, you can set values
# as long as you load the image with

# ```julia
# img = TiffImages.load(filepath; mmap=true, mode="r+")
# ```

# !!! warning
#     Setting values in the array writes those same values to disk!
#     Careless use of `mode="r+"` can easily corrupt raw data files.
#     You should omit `mode`, or use `mode="r"` (read-only), unless
#     you intend to rewrite files.

# #### Lazy operations

# One of the primary benefits of lazy-loading is avoiding unnecessary work for
# portions of the image that may never be accessed.
# I recommend using `MappedArrays` to continue the "laziness" of operations.

# !!! warning
#     `lazyio=true` caches each slice when you access it so operations that
#     involve slices will be fast, i.e. operations along the 1st and 2nd
#     dimensions of an image are quick. However, operations along the 3rd
#     dimension are slow.
#
#     For example, `img[:, :, 1]` is fast. `img[1, 1, :]` will be slower since
#     in the latter case, each whole slice has to be loaded to only grab a single
#     element
#
#     Performance across dimensions is more consistently good wtih `mmap=true`,
#     when the file supports it. Note that `mmap=true` falls back to `lazyio=true`,
#     so simply specifying `mmap=true` may not be sufficient.
#     TiffImages will print a warning the first time it happens.

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


# ### Incremental writing

# `TiffImages` also supports writing to a file via an append
# operation. As with most arrays, you need to provide an element type and a
# filepath, but we'll use the [`memmap`](@ref) function in place of `load`

using TiffImages #hide
#--------------
using ImageCore # reexports Gray and N0f8
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
