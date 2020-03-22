using Documenter
using TIFF

DocMeta.setdocmeta!(TIFF, :DocTestSetup, :(using TIFF); recursive=true)
makedocs(
    modules=[TIFF], 
    sitename="TIFF.jl",
    authors="Tamas Nagy and contributors",
    pages = [
        "Home" => "index.md",
        "Library" => [
            "Public" => joinpath("lib", "public.md"),
            "Extending" => joinpath("lib", "extend.md"),
        ],
        "Contributing" => "contributing.md"
    ]
)

deploydocs(
    repo = "github.com/tlnagy/TIFF.jl.git",
)