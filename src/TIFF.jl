module TIFF

using ColorTypes
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
include(joinpath("types", "common.jl"))
include(joinpath("types", "dense.jl"))
include("load.jl")

end # module
