using SnoopCompile
import Pkg

Pkg.activate(joinpath(dirname(@__DIR__), "test"))
Pkg.instantiate()
Pkg.precompile()

@warn "Remember to comment out the precompile block at the end of the module first"

tinf = @snoopi_deep include(joinpath(@__DIR__, "precomp_gen.jl"))

ttot, pcs = SnoopCompile.parcel(tinf)

pre_dir = joinpath(dirname(@__DIR__), "src")
temp_pre_dir = joinpath(@__DIR__, "precomp_files")

SnoopCompile.write(temp_pre_dir, pcs)

cp(joinpath(temp_pre_dir, "precompile_TiffImages.jl"), joinpath(pre_dir, "precompile.jl"), force=true)

# Version 1.7.0-DEV.599 (2021-02-23) results

# Test: no precompile statements out of 8.5968e-5
# Base.Multimedia: no precompile statements out of 0.000275989
# Base.SimdLoop: no precompile statements out of 0.000407908
# Base.Order: no precompile statements out of 0.000536852
# FileIO: no precompile statements out of 0.000550962
# Markdown: no precompile statements out of 0.0006239080000000001
# FixedPointNumbers: no precompile statements out of 0.001040202
# ColorVectorSpace: no precompile statements out of 0.001379413
# Logging: precompiled 0.001722304 out of 0.001722304
# OffsetArrays: no precompile statements out of 0.002296208
# Core: no precompile statements out of 0.0034895629999999998
# LinearAlgebra: precompiled 0.0013803869999999998 out of 0.004956093999999999
# InteractiveUtils: precompiled 0.00626247 out of 0.00626247
# Base.Threads: precompiled 0.009569629 out of 0.009569629
# SparseArrays: precompiled 0.012367197999999998 out of 0.012367197999999998
# Base.Iterators: precompiled 0.012117240999999999 out of 0.012684179
# ProgressMeter: precompiled 0.013705748 out of 0.013705748
# Downloads: precompiled 0.014950076 out of 0.014950076
# Base.Sort: precompiled 0.016226450999999996 out of 0.016226450999999996
# Random: precompiled 0.017393442 out of 0.017393442
# ColorTypes: precompiled 0.020498265 out of 0.023748921
# Base.IteratorsMD: precompiled 0.035884334000000004 out of 0.03903587000000001
# Documenter.DocMeta: precompiled 0.051472402 out of 0.051472402
# Documenter.Utilities.Markdown2: precompiled 0.05216909700000002 out of 0.055926490000000016
# ChainRulesCore: precompiled 0.06667838000000001 out of 0.06667838
# Base.Broadcast: precompiled 0.124451302 out of 0.13479977599999995
# DocStringExtensions: precompiled 0.2535032259999999 out of 0.25378781899999997
# Documenter.DocTests: precompiled 0.3671079589999999 out of 0.36790237199999987
# Documenter: precompiled 0.552544844 out of 0.552544844
# Base: precompiled 0.5551221220000002 out of 0.6030158669999999
# Documenter.Builder: precompiled 2.3401716290000003 out of 2.3410122970000007
# TiffImages: precompiled 3.5842173639999997 out of 3.6049806520000005
