using Documenter
using TiffImages

using Literate
using Images

EXAMPLE_DIR = joinpath(@__DIR__, "..", "examples")
EXAMPLES = filter(x->endswith(x, ".jl"), joinpath.(EXAMPLE_DIR, readdir(EXAMPLE_DIR)))
OUTPUT = joinpath(@__DIR__, "src", "examples")

for ex in EXAMPLES
    Literate.markdown(ex, OUTPUT, documenter = true)
end

DocMeta.setdocmeta!(TiffImages, :DocTestSetup, :(using TiffImages); recursive=true)
makedocs(
    format = Documenter.HTML(
        prettyurls=get(ENV, "CI", "false") == "true",
        assets =[
                asset("https://analytics.tamasnagy.com/js/script.js", class=:js, attributes=Dict(Symbol("data-domain") => "tamasnagy.com", :defer => ""))
            ],
    ),
    modules=[TiffImages],
    sitename="TiffImages.jl",
    authors="Tamas Nagy and contributors",
    warnonly = true,
    pages = [
        "Home" => "index.md",
        "Examples" => [
            "Reading TIFFs" => joinpath("examples", "reading.md"),
            "Writing TIFFs" => joinpath("examples", "writing.md"),
            "Lazy TIFFs" => joinpath("examples", "mmap_lazyio.md")
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
    push_preview = true
)