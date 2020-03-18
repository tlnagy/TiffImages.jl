using Documenter
using TIFF

DocMeta.setdocmeta!(TIFF, :DocTestSetup, :(using TIFF); recursive=true)
makedocs(modules=[TIFF], sitename="TIFF.jl")

deploydocs(
    repo = "github.com/tlnagy/TIFF.jl.git",
)