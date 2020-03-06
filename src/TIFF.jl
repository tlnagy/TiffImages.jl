module TIFF

using ColorTypes
using FileIO
using FixedPointNumbers

include("enum.jl")
include("utils.jl")
include("files.jl")
include("tags.jl")
include("ifds.jl")
include("arrays.jl")

end # module
