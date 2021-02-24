function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    Base.precompile(Tuple{typeof(load),String})   # time: 0.8531362
    Base.precompile(Tuple{typeof(save),String,Matrix{Gray{N0f8}}})   # time: 0.5170205
    Base.precompile(Tuple{typeof(read!),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Matrix{Gray{N0f8}},Val{COMPRESSION_PACKBITS}})   # time: 0.18825965
    Base.precompile(Tuple{Core.kwftype(typeof(load)),NamedTuple{(:verbose, :mmap), Tuple{Bool, Bool}},typeof(load),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}}})   # time: 0.1723125
    Base.precompile(Tuple{typeof(write),IOStream,DenseTaggedImage{GrayA{N0f8}, 2, UInt64, Matrix{GrayA{N0f8}}}})   # time: 0.16171266
    Base.precompile(Tuple{typeof(save),String,Matrix{RGB{Float64}}})   # time: 0.15845765
    Base.precompile(Tuple{typeof(save),String,Matrix{Gray{Float64}}})   # time: 0.14648879
    Base.precompile(Tuple{typeof(save),String,Matrix{RGB{N0f8}}})   # time: 0.14353837
    Base.precompile(Tuple{typeof(read!),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Matrix{Palette{N0f8}},Val{COMPRESSION_PACKBITS}})   # time: 0.11497961
    Base.precompile(Tuple{Core.kwftype(typeof(load)),NamedTuple{(:verbose, :mmap), Tuple{Bool, Bool}},typeof(load),TiffFile{UInt64, Stream{DataFormat{:TIFF}, IOStream}}})   # time: 0.113022365
    Base.precompile(Tuple{typeof(read),TiffFile{UInt64, Stream{DataFormat{:TIFF}, IOBuffer}},Type{Tag}})   # time: 0.066944726
    Base.precompile(Tuple{typeof(write),Stream{DataFormat{:TIFF}, IOStream},DenseTaggedImage{GrayA{N0f8}, 2, UInt64, Matrix{GrayA{N0f8}}}})   # time: 0.066800356
    Base.precompile(Tuple{typeof(write),Stream{DataFormat{:TIFF}, IOStream},DenseTaggedImage{Gray{N0f8}, 2, UInt32, Matrix{Gray{N0f8}}}})   # time: 0.06479182
    Base.precompile(Tuple{typeof(write),IOStream,DenseTaggedImage{RGB{Float64}, 3, UInt32, Array{RGB{Float64}, 3}}})   # time: 0.060670342
    Base.precompile(Tuple{typeof(read!),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Matrix{GrayA{N0f8}},Val{COMPRESSION_NONE}})   # time: 0.045707714
    Base.precompile(Tuple{Type{DenseTaggedImage},Array{RGB{Float64}, 3}})   # time: 0.039014105
    Base.precompile(Tuple{typeof(read!),Matrix{Gray{Float64}},TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},IFD{UInt32}})   # time: 0.032177236
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},IFD{UInt32}})   # time: 0.03194977
    Base.precompile(Tuple{typeof(show),IOContext{IOBuffer},IFD{UInt32}})   # time: 0.02842084
    Base.precompile(Tuple{typeof(read!),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Matrix{RGB{N0f8}},Val{COMPRESSION_NONE}})   # time: 0.028321235
    Base.precompile(Tuple{typeof(==),Tag{UInt16},Tag{UInt16}})   # time: 0.025600746
    Base.precompile(Tuple{typeof(read!),Matrix{Palette{N0f8}},TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},IFD{UInt32}})   # time: 0.02521157
    Base.precompile(Tuple{typeof(==),Tag{Vector{UInt16}},Tag{Vector{UInt16}}})   # time: 0.023760663
    Base.precompile(Tuple{typeof(read!),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Matrix{RGB{Float16}},Val{COMPRESSION_NONE}})   # time: 0.023287587
    Base.precompile(Tuple{typeof(read!),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Matrix{RGBA{N0f8}},Val{COMPRESSION_NONE}})   # time: 0.023152903
    Base.precompile(Tuple{typeof(read!),Matrix{RGB{Float16}},TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},IFD{UInt32}})   # time: 0.022414045
    Base.precompile(Tuple{typeof(read!),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Matrix{Gray{Q0f7}},Val{COMPRESSION_NONE}})   # time: 0.022239514
    Base.precompile(Tuple{typeof(read!),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Matrix{Gray{Float64}},Val{COMPRESSION_NONE}})   # time: 0.022171594
    Base.precompile(Tuple{typeof(read!),Matrix{RGBA{N0f8}},TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},IFD{UInt32}})   # time: 0.021391485
    Base.precompile(Tuple{typeof(read!),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Matrix{Gray{N0f8}},Val{COMPRESSION_NONE}})   # time: 0.02123404
    Base.precompile(Tuple{typeof(read!),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Matrix{RGB{Float64}},Val{COMPRESSION_NONE}})   # time: 0.021200674
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},IFD{UInt32}})   # time: 0.021150375
    Base.precompile(Tuple{typeof(read),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Type{Tag}})   # time: 0.021041602
    Base.precompile(Tuple{typeof(read!),Matrix{Gray{Q0f7}},TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},IFD{UInt32}})   # time: 0.020965552
    Base.precompile(Tuple{Type{PhotometricInterpretations},UInt16})   # time: 0.02094273
    Base.precompile(Tuple{typeof(read!),Matrix{Gray{N0f8}},TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},IFD{UInt32}})   # time: 0.02027843
    Base.precompile(Tuple{typeof(read!),Matrix{RGB{N0f8}},TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},IFD{UInt32}})   # time: 0.02018289
    Base.precompile(Tuple{typeof(read!),Matrix{RGB{Float64}},TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},IFD{UInt32}})   # time: 0.02010488
    Base.precompile(Tuple{typeof(read!),Matrix{GrayA{N0f8}},TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},IFD{UInt32}})   # time: 0.020045642
    Base.precompile(Tuple{typeof(write),TiffFile{UInt64, Stream{DataFormat{:TIFF}, IOStream}},Tag{Int64}})   # time: 0.018833784
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Rational{UInt32}})   # time: 0.016355174
    Base.precompile(Tuple{typeof(_constructifd),Matrix{GrayA{N0f8}},Type{UInt64}})   # time: 0.01615425
    Base.precompile(Tuple{typeof(==),Tag{Vector{Any}},Tag{Vector{Any}}})   # time: 0.014018073
    Base.precompile(Tuple{typeof(read!),Matrix{GrayA{N0f8}},TiffFile{UInt64, Stream{DataFormat{:TIFF}, IOStream}},IFD{UInt64}})   # time: 0.013356887
    Base.precompile(Tuple{Type{CompressionType},UInt16})   # time: 0.013091691
    Base.precompile(Tuple{typeof(==),Tag{String},Tag{String}})   # time: 0.01298185
    Base.precompile(Tuple{typeof(==),Tag{UInt32},Tag{UInt32}})   # time: 0.012306561
    Base.precompile(Tuple{typeof(==),Tag{Rational{UInt32}},Tag{Rational{UInt32}}})   # time: 0.011322744
    Base.precompile(Tuple{typeof(==),Tag{Int64},Tag{Int64}})   # time: 0.009839917
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Vector{Any}})   # time: 0.009679591
    Base.precompile(Tuple{typeof(getindex),DenseTaggedImage{Gray{Q0f7}, 3, UInt32, Array{Gray{Q0f7}, 3}},Colon,Colon,Int64})   # time: 0.008461196
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Tag{String}})   # time: 0.007452095
    Base.precompile(Tuple{typeof(write),TiffFile{UInt64, Stream{DataFormat{:TIFF}, IOStream}},IFD{UInt64}})   # time: 0.007410001
    Base.precompile(Tuple{typeof(load!),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},IFD{UInt32}})   # time: 0.007403022
    Base.precompile(Tuple{typeof(show),IOContext{IOBuffer},Tag{String}})   # time: 0.006368029
    Base.precompile(Tuple{typeof(write),TiffFile{UInt64, Stream{DataFormat{:TIFF}, IOStream}},Tag{UInt64}})   # time: 0.006161459
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Tag{UInt16}})   # time: 0.005960559
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Tag{UInt32}})   # time: 0.005946236
    Base.precompile(Tuple{typeof(==),Tag{Vector{Any}},Tag})   # time: 0.005465424
    Base.precompile(Tuple{Type{SampleFormats},UInt16})   # time: 0.004940535
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Tag{Vector{Any}}})   # time: 0.004425628
    Base.precompile(Tuple{typeof(read!),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},BitMatrix,Val{COMPRESSION_NONE}})   # time: 0.004010168
    Base.precompile(Tuple{typeof(show),IOContext{IOBuffer},Tag{Int64}})   # time: 0.003988138
    Base.precompile(Tuple{typeof(setindex!),IFD{UInt32},Vector{Any},TiffTag})   # time: 0.003884544
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Tag{Vector{UInt32}}})   # time: 0.003710196
    Base.precompile(Tuple{Type{ExtraSamples},UInt16})   # time: 0.003669783
    Base.precompile(Tuple{typeof(setindex!),IFD{UInt32},Tag{Vector{Float32}},UInt16})   # time: 0.003473605
    Base.precompile(Tuple{typeof(setindex!),IFD{UInt32},Tag{Rational{UInt32}},UInt16})   # time: 0.003378185
    Base.precompile(Tuple{typeof(setindex!),IFD{UInt32},Tag{Vector{Any}},UInt16})   # time: 0.003339198
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Tag{UInt16}})   # time: 0.003337144
    Base.precompile(Tuple{typeof(setindex!),IFD{UInt32},Int64,TiffTag})   # time: 0.003330334
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Tag{UInt32}})   # time: 0.003281216
    Base.precompile(Tuple{typeof(read),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Type{IFD}})   # time: 0.003261436
    Base.precompile(Tuple{typeof(write),TiffFile{UInt64, Stream{DataFormat{:TIFF}, IOStream}},Tag{String}})   # time: 0.003118473
    Base.precompile(Tuple{typeof(setindex!),IFD{UInt32},Tag{Vector{UInt32}},UInt16})   # time: 0.003060288
    Base.precompile(Tuple{typeof(setindex!),IFD{UInt32},Tag{Vector{Rational{UInt32}}},UInt16})   # time: 0.003004863
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Tag{String}})   # time: 0.002840864
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Tag{Vector{UInt16}}})   # time: 0.002743712
    Base.precompile(Tuple{typeof(reversebits),UInt16})   # time: 0.002475895
    Base.precompile(Tuple{typeof(write),TiffFile{UInt64, Stream{DataFormat{:TIFF}, IOStream}},Tag{UInt16}})   # time: 0.002377102
    Base.precompile(Tuple{typeof(write),TiffFile{UInt64, Stream{DataFormat{:TIFF}, IOStream}},Tag{UInt32}})   # time: 0.002330324
    Base.precompile(Tuple{Type{DenseTaggedImage},Matrix{GrayA{N0f8}},IFD{UInt64}})   # time: 0.002313145
    Base.precompile(Tuple{Type{TiffFile{UInt32, S} where S<:Stream}})   # time: 0.002307761
    Base.precompile(Tuple{typeof(delete!),IFD{UInt32},TiffTag})   # time: 0.00196244
    Base.precompile(Tuple{Type{TiffFile{UInt64, S} where S<:Stream}})   # time: 0.001846816
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Tag{Rational{UInt32}},Int64})   # time: 0.001842795
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Tag{Vector{UInt32}},Int64})   # time: 0.001810207
    Base.precompile(Tuple{typeof(write),TiffFile{UInt64, Stream{DataFormat{:TIFF}, IOStream}},Tag{Vector{UInt16}}})   # time: 0.001809206
    Base.precompile(Tuple{typeof(==),Tag{Vector{UInt16}},Tag})   # time: 0.001804639
    Base.precompile(Tuple{typeof(==),Tag{Rational{UInt32}},Tag})   # time: 0.001744052
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Tag{Int64},Int64})   # time: 0.001742653
    Base.precompile(Tuple{Type{ExtraSamples},Int64})   # time: 0.001733948
    Base.precompile(Tuple{typeof(==),Tag{String},Tag})   # time: 0.001720252
    Base.precompile(Tuple{typeof(==),Tag{Int64},Tag})   # time: 0.001519996
    Base.precompile(Tuple{typeof(write),TiffFile{UInt64, Stream{DataFormat{:TIFF}, IOStream}},Tag{String},Int64})   # time: 0.001491975
    Base.precompile(Tuple{Type{DenseTaggedImage},Matrix{RGB{N0f16}},IFD{UInt32}})   # time: 0.0014855
    Base.precompile(Tuple{typeof(interpretation),PhotometricInterpretations,ExtraSamples,Val{4}})   # time: 0.001481642
    Base.precompile(Tuple{Type{Tag},UInt16,Vector{Float32}})   # time: 0.001394724
    Base.precompile(Tuple{typeof(read!),TiffFile{UInt64, Stream{DataFormat{:TIFF}, IOStream}},Matrix{GrayA{N0f8}},Val{COMPRESSION_NONE}})   # time: 0.001387047
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Tag{String},Int64})   # time: 0.001385259
    Base.precompile(Tuple{typeof(write),TiffFile{UInt64, Stream{DataFormat{:TIFF}, IOBuffer}},Rational{UInt32}})   # time: 0.001370888
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Tag{Vector{Any}},Int64})   # time: 0.001290415
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},UInt16})   # time: 0.001252801
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},UInt32})   # time: 0.001246271
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOStream}},Tag{Vector{UInt16}},Int64})   # time: 0.001200158
    Base.precompile(Tuple{typeof(interpretation),PhotometricInterpretations,ExtraSamples,Val{2}})   # time: 0.001130745
    Base.precompile(Tuple{typeof(write),TiffFile{UInt64, Stream{DataFormat{:TIFF}, IOBuffer}},UInt64})   # time: 0.001085022
    Base.precompile(Tuple{typeof(setindex!),IFD{UInt32},ExtraSamples,TiffTag})   # time: 0.001067766
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Tag{String},Int64})   # time: 0.001026105
    Base.precompile(Tuple{typeof(write),TiffFile{UInt32, Stream{DataFormat{:TIFF}, IOBuffer}},Int64})   # time: 0.001022311
    Base.precompile(Tuple{typeof(setindex!),IFD{UInt32},Vector{UInt32},TiffTag})   # time: 0.001012777
end
