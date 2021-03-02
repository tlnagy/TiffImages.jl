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
using OrderedCollections
using PkgVersion
using ProgressMeter
using Base.Iterators

const PKGVERSION = @PkgVersion.Version 0

include("enum.jl")
include("utils.jl")
include("files.jl")
include("compression.jl")
include("tags.jl")
include("ifds.jl")
include("layout.jl")
include(joinpath("types", "common.jl"))
include(joinpath("types", "dense.jl"))
include(joinpath("types", "mmap.jl"))
include("load.jl")

@deprecate TiffFile(::Type{O}) where O<:Unsigned TiffFile{O}()

if Base.VERSION >= v"1.5.3"
    include("precompile.jl")
    _precompile_()
end

end # module
