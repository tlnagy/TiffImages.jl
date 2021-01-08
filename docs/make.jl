using Documenter
using TiffImages

using Literate
using Images

EXAMPLE_DIR = joinpath(@__DIR__, "..", "examples")
EXAMPLES = filter(x->endswith(x, ".jl"), joinpath.(EXAMPLE_DIR, readdir(EXAMPLE_DIR)))
OUTPUT = joinpath(@__DIR__, "src", "generated")

for ex in EXAMPLES
    Literate.markdown(ex, OUTPUT, documenter = true)
end

DocMeta.setdocmeta!(TiffImages, :DocTestSetup, :(using TiffImages); recursive=true)
makedocs(
    format = Documenter.HTML(
        prettyurls = true,
    ),
    modules=[TiffImages],
    sitename="TiffImages.jl",
    authors="Tamas Nagy and contributors",
    pages = [
        "Home" => "index.md",
        "Examples" => [
            "Writing TIFFs" => joinpath("generated", "writing.md")
        ],
        "Library" => [
            "Public" => joinpath("lib", "public.md"),
            "Extending" => [
                "Overview" => joinpath("lib", "extend", "index.md"),
                "Built-in Tags" => joinpath("lib", "extend", "tags.md"),
            ],
        ],
        "Contributing" => "contributing.md"
    ]
)

deploydocs(
    repo = "github.com/tlnagy/TiffImages.jl.git",
)