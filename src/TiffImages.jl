module TiffImages

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@compiler_options"))
    @eval Base.Experimental.@compiler_options optimize=1
end

using ColorTypes
using DocStringExtensions
using FileIO
using FixedPointNumbers
using IndirectArrays
using OffsetArrays
using DataStructures
using PkgVersion
using ProgressMeter
using Base.Iterators
using Inflate
using UUIDs
using Mmap
using SIMD

const PKGVERSION = @PkgVersion.Version 0

include("enum.jl")
include("utils.jl")
include("files.jl")
include("tags.jl")
include("ifds.jl")
include("compression.jl")
include("layout.jl")
include(joinpath("types", "common.jl"))
include(joinpath("types", "dense.jl"))
include(joinpath("types", "lazy.jl"))
include(joinpath("types", "mmapped.jl"))
include("load.jl")

export memmap, LazyBufferedTIFF, ifds

@deprecate TiffFile(::Type{O}) where O<:Unsigned TiffFile{O}()

## Precompilation helper
mktemp() do fpath, _
    for t in Any[N0f8, N0f16, Float32, Float64]
        for c in Any[Gray, GrayA, RGB, RGBA], sz in ((2, 2), (2, 2, 2))
            TiffImages.save(fpath, rand(c{t}, sz))
            TiffImages.load(fpath)
            let img = TiffImages.load(fpath; mmap=true) end
            let img = TiffImages.load(fpath; lazyio=true) end
            # On Windows, trying to delete a file before garbage-collecting
            # its corresponding mmapped-array results in an error.
            # Here, this manifests as an error in precompiling the package,
            # which is quite a serious problem.
            # Thus try hard to make sure we free all the temporaries.
            Sys.iswindows() && GC.gc()
        end
    end
end

end # module
