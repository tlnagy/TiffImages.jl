module TIFF

using ColorTypes
using FileIO
using FixedPointNumbers

include("enum.jl")
include("utils.jl")
include("files.jl")
include("tags.jl")
include("ifds.jl")
include(joinpath("types", "common.jl"))
include(joinpath("types", "dense.jl"))
include("load.jl")

end # module
