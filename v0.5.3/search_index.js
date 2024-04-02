var documenterSearchIndex = {"docs":
[{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"EditURL = \"https://github.com/tlnagy/TiffImages.jl/blob/master/examples/writing.jl\"","category":"page"},{"location":"examples/writing/#Writing-TIFFs","page":"Writing TIFFs","title":"Writing TIFFs","text":"","category":"section"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"This page is a tutorial for saving TIFFs using TiffImages.jl and covers some common use cases","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"Pages = [\"writing.md\"]\nDepth = 5","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"You might want to write TIFFs to disk too. Now this can be done quite simply with TiffImages.jl. Say you have some AbstractArray type that you want to save, here we'll call it data:","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"using Random\nusing Images # for nice inline images\n\nRandom.seed!(123)\ndata = rand(RGB{N0f8}, 10, 10)","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"note: Note\nTiffImages.jl only works with AbstractArrays with eltypes of <:Colorant because the writer needs to know how to represent the image data on disk. Make sure to convert your AbstractArrays using before passing them. See the common strategies section below for tips.","category":"page"},{"location":"examples/writing/#Simple-cases","page":"Writing TIFFs","title":"Simple cases","text":"","category":"section"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"In most simple cases, all you need to do is use the save function","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"using TiffImages\nTiffImages.save(\"test.tif\", data)","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"That's it! TiffImages will convert your data into its own internal file type and then rapidly write it to disk. See the writing section of Memory-mapping TIFFs for building a TIFF piece by piece.","category":"page"},{"location":"examples/writing/#Complex-cases","page":"Writing TIFFs","title":"Complex cases","text":"","category":"section"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"If you need more fine-grained control over what tags are included when the image is written, this section is for you!","category":"page"},{"location":"examples/writing/#Converting-to-TiffImages.jl's-TIFF-type","page":"Writing TIFFs","title":"Converting to TiffImages.jl's TIFF type","text":"","category":"section"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"Next lets convert data to a TIFF type","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"using TiffImages\nimg = TiffImages.DenseTaggedImage(data)","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"Wait nothing happened! Hang with me, lets take a closer look at our new object using the dump command. We can see that there's now new information associated with our data! TiffImages.jl usually represents TIFF images as simply the data and associated tags that describe the data","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"dump(img; maxdepth=1)","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"The tags are organized as a vector of what are called Image File Directories (IFDs). For a simple 2D image like what we have, the IFDs will be stored a vector of length=1. For 3D images, the length of the IFDs vector will equal the length of the image in the third dimension.","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"Lets take a look at what tags there are:","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"ifd = first(img.ifds) # since our data is 2D\nifd","category":"page"},{"location":"examples/writing/#Manipulating-TIFF-Tags","page":"Writing TIFFs","title":"Manipulating TIFF Tags","text":"","category":"section"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"These are some of the most basic tags that are required by the TIFF spec. We can even update it to add our own custom tags","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"ifd[TiffImages.IMAGEDESCRIPTION] = \"This is very important data\"\nifd","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"We can even add tags that aren't in the standard set in TiffImages.TiffTag as long as they are a UInt16","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"ifd[UInt16(34735)] = UInt16[1, 2, 3]\nifd","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"We can also delete tags if we decide we don't want them:","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"delete!(ifd, TiffImages.IMAGEDESCRIPTION)\nifd","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"warning: Warning\nCareful with delete!, if any of core tags are deleted, TiffImages.jl and other readers might fail to read the file","category":"page"},{"location":"examples/writing/#Saving-to-disk","page":"Writing TIFFs","title":"Saving to disk","text":"","category":"section"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"Once you're happy with your TIFF object, you can write it to disk as follows:","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"TiffImages.save(\"test.tif\", img)","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"And to just double check, we can load it right back in","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"TiffImages.load(\"test.tif\")","category":"page"},{"location":"examples/writing/#Strategies-for-saving-common-types","page":"Writing TIFFs","title":"Strategies for saving common types","text":"","category":"section"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"The general strategy for saving arrays will differ a bit depending on the type. The key step is the convert or reinterpret the arrays so that the elements are subtypes of Colors.Colorant","category":"page"},{"location":"examples/writing/#Unsigned-Integers","page":"Writing TIFFs","title":"Unsigned Integers","text":"","category":"section"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"Say you want to save a 3D array of small integers as grayscale values.","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"data2 = rand(UInt8.(1:255), 5, 10)\neltype(data2)","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"You can't directly save the data2 since TiffImages.jl needs some color information to properly save the file. You can use reinterpret to accomplish this:","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"grays = reinterpret(Gray{N0f8}, data2)\nimg2 = TiffImages.DenseTaggedImage(grays)","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"Here the data are first reinterpreted as N0f8s, which is a FixedPointNumber then wrapped with a Gray type that marks this as a grayscale image. TiffImages.jl uses this information to update the TIFF tags","category":"page"},{"location":"examples/writing/#Floating-point-numbers","page":"Writing TIFFs","title":"Floating point numbers","text":"","category":"section"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"With RGB we can reinterpret the first dimension of a 3D array as the 3 different color components (red, green, and blue):","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"data = rand(Float64, 3, 5, 10);\ncolors = dropdims(reinterpret(RGB{eltype(data)}, data), dims=1) # drop first dimension\nimg3 = TiffImages.DenseTaggedImage(colors)","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"Here we dropped the first dimension since it was collapsed into the RGB type when we ran the reinterpret command.","category":"page"},{"location":"examples/writing/#Signed-integers","page":"Writing TIFFs","title":"Signed integers","text":"","category":"section"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"Say you want to save data that has negative integer values. In that case, you can't use N0f8, etc because those only worked for unsigned integers. You have to instead use Q0f63, etc, which is a different kind of fixed point number that uses one bit for the sign info (that's why it's Q0f63, not Q0f64!)","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"data = rand(-100:100, 5, 5)","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"img4 = TiffImages.DenseTaggedImage(reinterpret(Gray{Q0f63}, data))\nprintln(img4.ifds[1])","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"As you can see the SAMPLEFORMATS and BITSPERSAMPLE tags correctly updated to show that this TIFF contains signed integers and 64-bit data, respectively.","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"warning: Warning\nCurrently, several of the display libraries struggle with showing Colorants backed by a signed type so you might run into errors, but the data will still save properly","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"","category":"page"},{"location":"examples/writing/","page":"Writing TIFFs","title":"Writing TIFFs","text":"This page was generated using Literate.jl.","category":"page"},{"location":"lib/extend/tags/#Built-in-Tags","page":"Built-in Tags","title":"Built-in Tags","text":"","category":"section"},{"location":"lib/extend/tags/","page":"Built-in Tags","title":"Built-in Tags","text":"Tags are stored as an enum called TiffTag","category":"page"},{"location":"lib/extend/tags/","page":"Built-in Tags","title":"Built-in Tags","text":"TiffImages.TiffTag","category":"page"},{"location":"lib/extend/tags/#TiffImages.TiffTag","page":"Built-in Tags","title":"TiffImages.TiffTag","text":"primitive type TiffTag <: Enum{Int32} 32\n\nList of many common named TIFF Tags. This is not an exhaustive list but should cover most cases.\n\n\n\n\n\n","category":"type"},{"location":"lib/extend/tags/#Full-list-of-built-in-tags","page":"Built-in Tags","title":"Full list of built-in tags","text":"","category":"section"},{"location":"lib/extend/tags/","page":"Built-in Tags","title":"Built-in Tags","text":"using TiffImages, Markdown\ntags = instances(TiffImages.TiffTag)\nmapping = collect.(zip(Int.(tags), string.(tags)))\ninsert!(mapping, 1, [\"Tag ID\", \"Tag Description\"])\nMarkdown.Table(mapping, fill(:l, length(mapping)))","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"EditURL = \"https://github.com/tlnagy/TiffImages.jl/blob/master/examples/mmap.jl\"","category":"page"},{"location":"examples/mmap/#Memory-mapping-TIFFs","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"","category":"section"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"If you're running into memory-limitations when working with large datasets, you can memory-map the file so that it looks and behaves as if it were loaded, but it instead lazily loads data only when needed.","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"Pages = [\"mmap.md\"]\nDepth = 5","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"get_example(name) = download(\"https://github.com/tlnagy/exampletiffs/blob/master/$name?raw=true\") #hide\nfilepath = get_example(\"mri.tif\");                                                                #hide\nnothing #hide","category":"page"},{"location":"examples/mmap/#Memory-mapped-loading","page":"Memory-mapping TIFFs","title":"Memory-mapped loading","text":"","category":"section"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"Loading is very similar to Reading TIFFs, except with the addition of the mmap=true flag. Here, we're loading mri.tif from the tlnagy/exampletiffs repo","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"using TiffImages\nimg = TiffImages.load(filepath; mmap=true);\nnothing #hide","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"The memory-mapped img will behave much the same as a normal eagerly loaded image:","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"size(img)","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"Display the 2nd slice","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"img[:, :, 2]","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"Currently, TiffImages does not support inplace mutating operations on memory-mapped files. That is, using setindex! and friends will throw an error.","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"#img[:, :, 2] .= 0.0 # throws an error","category":"page"},{"location":"examples/mmap/#Lazy-operations","page":"Memory-mapping TIFFs","title":"Lazy operations","text":"","category":"section"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"One of the primary benefits of memory-mapping is that it's lazy, that is, we're avoiding doing any unnecessary work. I recommend using MappedArrays to continue the \"laziness\" of operations to avoid any extra work.","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"warning: Warning\nTiffImages caches each slice when you access it so operations that involve slices will be fast, i.e. operations along the 1st and 2nd dimensions of an image are quick, operations along the 3rd dimension are slow.For example, img[:, :, 1] is fast. img[1, 1, :] will be slower since in the latter case, each whole slice has to be loaded to only grab a single element","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"using ColorTypes\nusing MappedArrays\n\neltype(img)","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"We can lazily convert our data for only the slices we end up actually displaying","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"gray_img = of_eltype(Gray, img);\nnothing #hide","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"Lets lazily load a slice from disk and then convert only that one to gray","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"slice = gray_img[:, :, 1]","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"We can check to make sure its eltype is correct:","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"eltype(slice)","category":"page"},{"location":"examples/mmap/#Example:-Maximum-intensity-projection","page":"Memory-mapping TIFFs","title":"Example: Maximum intensity projection","text":"","category":"section"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"It's pretty straigtforward to do a max-intensity projection:","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"dropdims(maximum(gray_img, dims=3), dims=3)","category":"page"},{"location":"examples/mmap/#Memory-mapped-writing","page":"Memory-mapping TIFFs","title":"Memory-mapped writing","text":"","category":"section"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"TiffImages also supports writing to a memory-mapped file via an append operation. As with most arrays, you need to provide an element type and a filepath, but we'll use the memmap function in place of load","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"using TiffImages #hide","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"using Images # reexports Gray and N0f8\nimg2 = memmap(Gray{N0f8}, \"test.tif\")","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"note: Note\nFor data-integrity reasons, TiffImages will not allow you to append to an pre-existing file and will throw an error if a file exists at the filepath that you provide.","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"Say you have the following data:","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"slice = rand(Gray{N0f8}, 256, 256)","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"You can then push new data to the img2 object and it will eagerly write that data to disk.","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"push!(img2, slice)","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"The first slice sets the XY dimensions of the TIFF and subsequent slices must have the same dimensions as the first.","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"push!(img2, rand(Gray{N0f8}, 256, 256))","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"The memory-mapped object also behaves like an array and supports most array operations (other than inplace mutating ones like setindex!)","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"size(img2)","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"To read a slice that you just wrote:","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"img2[:, :, 2]","category":"page"},{"location":"examples/mmap/#XL-files","page":"Memory-mapping TIFFs","title":"XL files","text":"","category":"section"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"If you're going to be writing lots of data to disk (4GB+) then it can be helpful to set the bigtiff flag to true so that TiffImages can use 64-bit offsets. You'll see that the addressable space sky rockets:","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"img3 = memmap(Gray{N0f16}, \"test.btif\"; bigtiff=true)","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"","category":"page"},{"location":"examples/mmap/","page":"Memory-mapping TIFFs","title":"Memory-mapping TIFFs","text":"This page was generated using Literate.jl.","category":"page"},{"location":"contributing/#Contributing","page":"Contributing","title":"Contributing","text":"","category":"section"},{"location":"contributing/","page":"Contributing","title":"Contributing","text":"Supporting all TIFFs is non-trivial and I would greatly appreciate any help from the community in identifying edge cases.","category":"page"},{"location":"contributing/#Add-edge-case-TIFFs","page":"Contributing","title":"Add edge case TIFFs","text":"","category":"section"},{"location":"contributing/","page":"Contributing","title":"Contributing","text":"There is incredible diversity in the TIFF ecosystem so much so that there is a backronym \"Thousand Incompatible File Formats\" to describe it. I have tried to establish a good baseline test set of TIFFs that should guarantee that TiffImages.jl should \"just work tm\" for most people, but if you have a TIFF that you run into that breaks TiffImages.jl please do the following:","category":"page"},{"location":"contributing/","page":"Contributing","title":"Contributing","text":"create a pull request against the example TIFF repo adding the file. The smaller the file, the better.\nupdate the README table with license information, etc.\nOpen an issue against TiffImages.jl with the error message and the expected result","category":"page"},{"location":"lib/extend/#Extending-TiffImages.jl","page":"Overview","title":"Extending TiffImages.jl","text":"","category":"section"},{"location":"lib/extend/","page":"Overview","title":"Overview","text":"If you want to extend TiffImages.jl to add support for more features or change how TIFF data is loaded, you have come to right place.","category":"page"},{"location":"lib/extend/#Types","page":"Overview","title":"Types","text":"","category":"section"},{"location":"lib/extend/","page":"Overview","title":"Overview","text":"TiffImages.TiffFile\nTiffImages.IFD\nTiffImages.Tag\nTiffImages.Iterable\nTiffImages.RemoteData","category":"page"},{"location":"lib/extend/#TiffImages.TiffFile","page":"Overview","title":"TiffImages.TiffFile","text":"mutable struct TiffFile{O<:Unsigned, S<:FileIO.Stream}\n\n-> TiffFile\n\nWrap io with helper parameters to keep track of file attributes.\n\nuuid\nA unique identifier for this file\nfilepath\nThe relative path to this file\nio\nThe file stream\nfirst_offset\nLocation of the first IFD in the file stream\nneed_bswap\nWhether this file has a different endianness than the host computer\n\n\n\n\n\n","category":"type"},{"location":"lib/extend/#TiffImages.IFD","page":"Overview","title":"TiffImages.IFD","text":"struct IFD{O<:Unsigned}\n\nAn image file directory is a sorted collection of the tags representing this plane in the TIFF file. They behave like dictionaries except that tags aren't required to be unique, so given an IFD called ifd, we can add new tags as follows: \n\njulia> ifd[TiffImages.IMAGEDESCRIPTION] = \"Some details\";\n\njulia> ifd[TiffImages.IMAGEWIDTH] = 512;\n\njulia> ifd\nIFD, with tags:\n\tTag(IMAGEWIDTH, 512)\n\tTag(IMAGEDESCRIPTION, \"Some details\")\n\nnote: Note\nTags are not required to be unique! See TiffImages.Iterable for how to work with duplicate tags.\n\n\n\n\n\n","category":"type"},{"location":"lib/extend/#TiffImages.Tag","page":"Overview","title":"TiffImages.Tag","text":"struct Tag{T}\n\nIn-memory representation of Tiff Tags, which are essentially key value pairs. The data field can either be a String, a Number, an Array of bitstypes, or a RemoteData type.\n\ntag\ndata\n\n\n\n\n\n","category":"type"},{"location":"lib/extend/#TiffImages.Iterable","page":"Overview","title":"TiffImages.Iterable","text":"A wrapper to force getindex to return the underlying array instead of only the first element. Usually the first element is sufficient, but sometimes access to the array is needed (to add duplicate entries or access them).\n\njulia> using TiffImages: Iterable\n\njulia> ifd[TiffImages.IMAGEDESCRIPTION] = \"test\"\n\"test\"\n\njulia> ifd[Iterable(TiffImages.IMAGEDESCRIPTION)] # since wrapped with Iterable, returns array\n1-element Vector{TiffImages.Tag}:\n Tag(IMAGEDESCRIPTION, \"test\")\n\njulia> ifd[Iterable(TiffImages.IMAGEDESCRIPTION)] = \"test2\" # since wrapped with Iterable, it appends\n\"test2\"\n\njulia> ifd\nIFD, with tags: \n\tTag(IMAGEDESCRIPTION, \"test\")\n\tTag(IMAGEDESCRIPTION, \"test2\")\n\n\n\n\n\n\n","category":"type"},{"location":"lib/extend/#TiffImages.RemoteData","page":"Overview","title":"TiffImages.RemoteData","text":"RemoteData\n\nA placeholder type to describe the location and properties of remote data that is too large to fit directly in a tag's spot in the IFD. Calling TiffImages.load! on an IFD object replaces all RemoteDatas with the respective data.\n\nposition\nPosition of this data in the stream\ncount\nThe length of the data\n\n\n\n\n\n","category":"type"},{"location":"lib/extend/#Functions","page":"Overview","title":"Functions","text":"","category":"section"},{"location":"lib/extend/","page":"Overview","title":"Overview","text":"TiffImages.load!\nTiffImages.sizeof","category":"page"},{"location":"lib/extend/#TiffImages.load!","page":"Overview","title":"TiffImages.load!","text":"load!(tf, ifd)\n\n\nUpdates an TiffImages.IFD by replacing all instances of the placeholder type TiffImages.RemoteData with the actual data from the file tf.\n\n\n\n\n\n","category":"function"},{"location":"lib/extend/#Base.sizeof","page":"Overview","title":"Base.sizeof","text":"sizeof(file)\n\nNumber of bytes that file's header will use on disk\n\n\n\n\n\nsizeof(tag::TiffImages.Tag)\n\nMinimum number of bytes that the data in tag will use on disk.\n\nnote: Note\nActual space on disk will be different because the tag's representation depends on the file's offset. For example, given a 2 bytes of data in tag and a file with UInt32 offsets, the actual usage on disk will be sizeof(UInt32)=4 for the data + tag overhead\n\n\n\n\n\nsizeof(ifd)\n\nNumber of bytes that an IFD will use on disk.\n\n\n\n\n\n","category":"function"},{"location":"lib/public/#Public-interface","page":"Public","title":"Public interface","text":"","category":"section"},{"location":"lib/public/#Reading/Writing","page":"Public","title":"Reading/Writing","text":"","category":"section"},{"location":"lib/public/","page":"Public","title":"Public","text":"TiffImages.load\nmemmap","category":"page"},{"location":"lib/public/#TiffImages.load","page":"Public","title":"TiffImages.load","text":"load(filepath; verbose, mmap)\n\n\nLoads a TIFF image. Optional flags verbose and mmap are set to true and false by default, respectively. Setting the former to false will hide the loading bar, while setting the later to true will memory-mapped the image.\n\nSee Memory-mapping TIFFs for more details about memory-mapping\n\n\n\n\n\n","category":"function"},{"location":"lib/public/#TiffImages.memmap","page":"Public","title":"TiffImages.memmap","text":"memmap(T, filepath; bigtiff)\n\nCreate a new memory-mapped file ready with element type T for appending future slices. The bigtiff flag, if true, allows 64-bit offsets for data larger than ~4GB. \n\njulia> using ColorTypes, FixedPointNumbers # for Gray{N0f8} type\n\njulia> img = memmap(Gray{N0f8}, \"test.tif\"); # make memory-mapped image\n\njulia> push!(img, rand(Gray{N0f8}, 100, 100)); \n\njulia> push!(img, rand(Gray{N0f8}, 100, 100)); \n\njulia> size(img)\n(100, 100, 2)\n\n\n\n\n\n","category":"function"},{"location":"lib/public/#Output-Types","page":"Public","title":"Output Types","text":"","category":"section"},{"location":"lib/public/","page":"Public","title":"Public","text":"TiffImages.DenseTaggedImage\nTiffImages.DiskTaggedImage","category":"page"},{"location":"lib/public/#TiffImages.DiskTaggedImage","page":"Public","title":"TiffImages.DiskTaggedImage","text":"mutable struct DiskTaggedImage{T<:Colorant, O<:Unsigned, AA<:AbstractArray} <: TiffImages.AbstractDenseTIFF{T<:Colorant, 3}\n\nA type to represent memory-mapped TIFF data. Useful for opening and operating on images too large to store in memory.\n\nfile\nPointer to keep track of the backing file\n\nifds\nThe associated tags for each slice in this array\n\ndims\ncache\nAn internal cache to fill reading from disk\n\ncache_index\nThe index of the currently loaded slice\n\nlast_ifd_offset\nPosition of last loaded IFD, updated whenever a slice is appended\n\nreadonly\nA flag tracking whether this file is editable\n\n\n\n\n\n","category":"type"},{"location":"#TiffImages.jl","page":"Home","title":"TiffImages.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Pure-Julia TIFF reader and writer with a focus on correctness 🧐","category":"page"},{"location":"","page":"Home","title":"Home","text":"TIFF (Tagged Image File Format) is a notoriously flexible file format that is very difficult to support properly so why not just link libtiff and call it a day? Because Julia developers are greedy. I wanted to design a clean, minimal, and standards-compliant TIFF reader and writer that can have the speed and compliance of libtiff while adding modern features like streaming, out-of-memory support, and fancy color support. I wanted to design it to be extensible such that packages like OMETIFF.jl can hook right in with minimal overhead. I wanted to leverage the wonderful Julia Arrays ecosystem to do as much lazily and flexibly as possible.","category":"page"},{"location":"#Features","page":"Home","title":"Features","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"TiffImages.jl supports:","category":"page"},{"location":"","page":"Home","title":"Home","text":"The TIFF 6.0 baseline spec\nThorough testing\nHDR images stored as 32bit or 64bit floats\nBigTIFFs\nMemory-mapped loading/writing","category":"page"},{"location":"#Usage","page":"Home","title":"Usage","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Check out the examples to see how to use TiffImages.jl","category":"page"},{"location":"","page":"Home","title":"Home","text":"Pages = [\"examples/reading.md\", \"examples/writing.md\", \"examples/mmap.md\"]\nDepth = 1","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"EditURL = \"https://github.com/tlnagy/TiffImages.jl/blob/master/examples/reading.jl\"","category":"page"},{"location":"examples/reading/#Reading-TIFFs","page":"Reading TIFFs","title":"Reading TIFFs","text":"","category":"section"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"Loading most TIFFs should just work, see Writing TIFFs for more advanced manipulation of TIFF objects. But we'll quickly run through a common use cases.","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"Pages = [\"reading.md\"]\nDepth = 5","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"get_example(name) = download(\"https://github.com/tlnagy/exampletiffs/blob/master/$name?raw=true\") #hide\nfilepath = get_example(\"spring.tif\");                                                             #hide\nnothing #hide","category":"page"},{"location":"examples/reading/#Basic-loading","page":"Reading TIFFs","title":"Basic loading","text":"","category":"section"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"At its most basic, we can just point TiffImages.jl to the filepath of an image and it will attempt to load it. Here, we're loading spring.tif from the tlnagy/exampletiffs repo","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"using TiffImages\nimg = TiffImages.load(filepath)","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"If you're a graphical environment, you can load the Images.jl repo to get a nice graphical representation of your image. If you're in the REPL, I highly recommend the ImageInTerminal.jl package for some visual feedback.","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"Continuing on, img here behaves exactly as you would expect a Julian array to despite the funky type signature","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"typeof(img)","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"Everything should behave as expected","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"eltype(img)","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"note: Note\nIf your reaction to this element type is \"Whoa! What is that?\", I highly recommend reading JuliaImages' primer on colors and types. TiffImages is well integrated with the JuliaImages ecosystem so the tutorials there are quite helpful for learning how to interact with the TiffImages' outputs","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"Accessing and setting data should work as expected","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"img[160:180, 50]","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"img[160:180, 50] .= 1.0\nimg","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"","category":"page"},{"location":"examples/reading/","page":"Reading TIFFs","title":"Reading TIFFs","text":"This page was generated using Literate.jl.","category":"page"}]
}
