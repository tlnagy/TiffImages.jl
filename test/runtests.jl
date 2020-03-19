using Documenter
using Test
using TIFF

DocMeta.setdocmeta!(TIFF, :DocTestSetup, :(using TIFF); recursive=true)
doctest(TIFF)