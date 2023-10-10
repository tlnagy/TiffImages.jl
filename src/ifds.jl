import .Iterators.partition

"""
    $(TYPEDEF)

An image file directory is a sorted collection of the tags representing this
plane in the TIFF file. They behave like dictionaries except that tags aren't
required to be unique, so given an IFD called `ifd`, we can add new tags as
follows:

```jldoctest; setup = :(ifd = TiffImages.IFD(UInt32))
julia> ifd[TiffImages.IMAGEDESCRIPTION] = "Some details";

julia> ifd[TiffImages.IMAGEWIDTH] = 512;

julia> ifd
IFD, with tags:
	Tag(IMAGEWIDTH, 512)
	Tag(IMAGEDESCRIPTION, "Some details")
```

!!! note
    Tags are not required to be unique! See [`TiffImages.Iterable`](@ref) for
    how to work with duplicate tags.
"""
struct IFD{O <: Unsigned}
    tags::DefaultDict{UInt16, Vector{Tag}, DataType}
end

IFD(::Type{O}) where {O <: Unsigned} = IFD{O}(DefaultDict{UInt16, Vector{Tag}}(Vector{Tag}))
IFD(::Type{O}, tags) where {O <: Unsigned} = IFD{O}(tags)

"""
A wrapper to force getindex to return the underlying array instead of only the
first element. Usually the first element is sufficient, but sometimes access to
the array is needed (to add duplicate entries or access them).

```jldoctest; setup = :(ifd = TiffImages.IFD(UInt32))
julia> using TiffImages: Iterable

julia> ifd[TiffImages.IMAGEDESCRIPTION] = "test"
"test"

julia> ifd[Iterable(TiffImages.IMAGEDESCRIPTION)] # since wrapped with Iterable, returns array
1-element Vector{TiffImages.Tag}:
 Tag(IMAGEDESCRIPTION, "test")

julia> ifd[Iterable(TiffImages.IMAGEDESCRIPTION)] = "test2" # since wrapped with Iterable, it appends
"test2"

julia> ifd
IFD, with tags:
	Tag(IMAGEDESCRIPTION, "test")
	Tag(IMAGEDESCRIPTION, "test2")

```
"""
struct Iterable{T}
    key::T
end

Base.length(ifd::IFD) = sum(map(length, values(ifd.tags)))
Base.keys(ifd::IFD) = keys(ifd.tags)
Base.values(ifd::IFD) = values(ifd.tags)
Base.iterate(ifd::IFD) = iterate(ifd.tags)
Base.iterate(ifd::IFD, n::Int) = iterate(ifd.tags, n)

Base.getindex(ifd::IFD, key::Iterable{TiffTag}) = getindex(ifd, Iterable(UInt16(key.key)))
Base.getindex(ifd::IFD, key::Iterable{UInt16}) = getindex(ifd.tags, key.key)
Base.getindex(ifd::IFD, key::TiffTag) = getindex(ifd, UInt16(key))
Base.getindex(ifd::IFD, key::UInt16) = first(getindex(ifd.tags, key))

getdata(f::F, ifd::IFD, key::TiffTag, default) where F = getdata(f, ifd, UInt16(key), default)
function getdata(f::F, ifd::IFD, key::UInt16, default) where F
    val = get(ifd.tags, key, nothing)
    val === nothing && return default
    return f(first(val).data)
end
getdata(ifd::IFD, key, default) = getdata(identity, ifd, key, default)

Base.in(key::TiffTag, v::IFD) = in(UInt16(key), v)
Base.in(key::UInt16, v::IFD) = in(key, keys(v))
Base.delete!(ifd::IFD, key::TiffTag) = delete!(ifd, UInt16(key))
Base.delete!(ifd::IFD, key::UInt16) = delete!(ifd.tags, key)

Base.similar(::IFD{O}) where {O <: Unsigned} = IFD(O)
Base.merge(ifd::IFD{O}, other::IFD) where {O <: Unsigned} = IFD(O, DefaultDict(Vector{Int}, merge(ifd.tags, other.tags)))

Base.setindex!(ifd::IFD, value::Tag, key::UInt16) = setindex!(ifd.tags, [value], key)
Base.setindex!(ifd::IFD, value::Tag, key::TiffTag) = setindex!(ifd, value, UInt16(key))

Base.setindex!(ifd::IFD, value, key::TiffTag) = setindex!(ifd, value, UInt16(key))
Base.setindex!(ifd::IFD, value, key::UInt16) = setindex!(ifd, Tag(key, value), key)

Base.setindex!(ifd::IFD, value, key::Iterable{TiffTag}) = setindex!(ifd, value, Iterable(UInt16(key.key)))
Base.setindex!(ifd::IFD, value, key::Iterable{UInt16}) = setindex!(ifd, Tag(key.key, value), key)
Base.setindex!(ifd::IFD, value::Tag, key::Iterable{UInt16}) = push!(ifd.tags[key.key], value)

function isloaded(ifd::IFD)
    for tags in values(ifd.tags)
        for tag in tags
            (!isloaded(tag)) && return false
        end
    end
    true
end

"""
    sizeof(ifd)

Number of bytes that an IFD will use on disk.
"""
function Base.sizeof(ifd::IFD{O}) where {O}
    sz = O == UInt32 ? 2 : sizeof(O)
    for tags in values(ifd)
        for tag in tags
            # tag, data, length, and data
            sz += 2 + 2 + sizeof(O) + sizeof(O)
            if sizeof(tag) > sizeof(O) # if data in tag is larger than slot
                sz += sizeof(tag) # we have add all the additional bytes
            end
        end
    end
    sz += sizeof(O) # slot for subsequent IFD locations
end
"""
    $SIGNATURES

Checks if the data in this IFD is contiguous on disk. Striped data can be read
faster as one contiguous chunk if possible.
"""
function iscontiguous(ifd::IFD)
    if !(ROWSPERSTRIP in ifd) || nrows(ifd) <= ifd[ROWSPERSTRIP].data
        return true
    else
        return all(diff(ifd[STRIPOFFSETS].data) .== ifd[STRIPBYTECOUNTS].data[1:end-1])
    end
end

"""
    $(SIGNATURES)

Updates an [`TiffImages.IFD`](@ref) by replacing all instances of the
placeholder type [`TiffImages.RemoteData`](@ref) with the actual data from the
file `tf`.
"""
function load!(tf::TiffFile, ifd::IFD)
    for key in sort(collect(keys(ifd)))
        tags = ifd[Iterable(key)]
        for (idx, tag) in enumerate(tags)
            tags[idx] = load(tf, tag)
        end
    end
end

function Base.show(io::IO, ifd::IFD)
    print(io, "IFD, with tags: ")
    for key in sort(collect(keys(ifd)))
        tags = ifd[Iterable(key)]
        for tag in tags
            print(io, "\n\t", tag)
        end
    end
end

function Base.read(tf::TiffFile{O}, ::Type{IFD}) where O <: Unsigned
    # Regular TIFF's use 16bits instead of 32 bits for entry data
    N = O == UInt32 ? read(tf, UInt16) : read(tf, O)

    entries = IFD(O)

    for i in 1:N
        tag = read(tf, Tag)
        push!(entries[Iterable(tag.tag)], tag)
    end

    next_ifd = Int(read(tf, O))
    entries, next_ifd
end

function Base.iterate(file::TiffFile{O}) where {O}
    seek(file.io, file.first_offset)
    iterate(file, (read(file, IFD)))
end

"""
    iterate(file, state) -> IFD, Int

Advances the iterator to the next IFD.

**Output**
- `Vector{Int}`: Offsets within file for all strips corresponding to the current
   IFD
- `Int`: Offset of the next IFD
"""
function Base.iterate(file::TiffFile, state::Tuple{Union{IFD{O}, Nothing}, Int}) where {O}
    curr_ifd, next_ifd_offset = state
    # if current element doesn't exist, exit
    (curr_ifd == nothing) && return nothing
    (next_ifd_offset <= 0) && return (curr_ifd, (nothing, 0))

    seek(file.io, next_ifd_offset)
    next_ifd, next_ifd_offset = read(file, IFD)

    return (curr_ifd, (next_ifd, next_ifd_offset))
end

"""
    $(TYPEDEF)

A strip is a contiguous block of separately-encoded image data. A TIFF
file will typically have multiple strips, each decoding to multiple rows of
pixels in the image

$(FIELDS)
"""
struct TiffFileStrip{O, T}
    """Strip data"""
    io::IOBuffer

    """The IFD corresponding to this strip"""
    ifd::IFD{O}
end

Base.read!(tfs::TiffFileStrip, arr::AbstractArray) = read!(tfs.io, arr)
Base.bytesavailable(tfs::TiffFileStrip) = bytesavailable(tfs.io)

function Base.read!(target::AbstractArray{T, N}, tf::TiffFile{O, S}, ifd::IFD{O}) where {T, N, O, S}
    offsets = istiled(ifd) ? ifd[TILEOFFSETS].data : ifd[STRIPOFFSETS].data
    compression = getdata(CompressionType, ifd, COMPRESSION, COMPRESSION_NONE)

    rtype = rawtype(ifd)
    spp = nsamples(ifd)
    rows = nrows(ifd)
    cols = ncols(ifd)
    samples = reinterpret(rtype, target)

    cmprssn = compression == COMPRESSION_NONE ? "uncompressed" : "compressed"
    @debug "reading $(cmprssn), $(istiled(ifd) ? "tiled" : "striped"), $(isplanar(ifd) ? "planar" : "chunky") image"

    # number of input bytes in each strip or tile
    encoded_bytes = istiled(ifd) ? ifd[TILEBYTECOUNTS].data : ifd[STRIPBYTECOUNTS].data

    # number of samples (pixels * channels) in each strip or tile
    strip_samples::Vector{Int} = []
    if istiled(ifd)
        @debug "tile size: $(tilecols(ifd)) x $(tilerows(ifd))"
        # tiled images are always padded to tile boundaries
        strip_samples = map(_ -> tilecols(ifd) * tilerows(ifd) * (isplanar(ifd) ? 1 : spp), encoded_bytes)
    else
        nstrips = length(encoded_bytes)
        rowsperstrip = getdata(Int, ifd, ROWSPERSTRIP, rows)

        if isplanar(ifd)
            # planar files will have separate strips or tiles for each channel
            temp = fill(rowsperstrip * cols, cld(rows, rowsperstrip))
            temp[end] = (rows - (rowsperstrip * (length(temp) - 1))) * cols
            strip_samples = repeat(temp, spp)
        else
            strip_samples = fill(rowsperstrip * cols * spp, nstrips)
            strip_samples[end] = (rows - (rowsperstrip * (nstrips - 1))) * cols * spp
        end

        @assert sum(strip_samples) == rows * cols * spp
    end

    parallel_enabled = something(tryparse(Bool, get(ENV, "JULIA_IMAGES_PARALLEL", "1")), false)
    do_parallel = parallel_enabled && rows * cols > 250_000 # pixels

    if !iscontiguous(ifd) || compression != COMPRESSION_NONE
        start = 1
        comp = Val(compression)
        tasks::Vector{Task} = []
        for (offset, len, bytes) in zip(offsets, strip_samples, encoded_bytes)
            seek(tf, offset)
            arr = view(samples, start:(start+len-1))
            data = Vector{UInt8}(undef, bytes)
            read!(tf, data)
            tfs = TiffFileStrip{O, rtype}(IOBuffer(data), ifd)

            function go(tfs, arr, comp)
                read!(tfs, arr, comp)
                reverse_prediction!(tfs, arr)
            end

            if do_parallel
                push!(tasks, Threads.@spawn go(tfs, arr, comp))
            else
                go(tfs, arr, comp)
            end

            start += len
        end

        for task in tasks
            wait(task)
        end
    else
        seek(tf, first(offsets))
        read!(tf, target, compression)
    end

    if isplanar(ifd)
        samplesv = vec(samples)
        temp = deplane(samplesv, spp)
        GC.@preserve samplesv temp target begin
            memcpy(pointer(samplesv), pointer(temp), sizeof(target))
        end
    end
end

function Base.write(tf::TiffFile{O}, ifd::IFD{O}) where {O <: Unsigned}
    if !isloaded(ifd)
        error("Cannot write unloaded IFDs. Use `load!` to populate tags with remote data")
    end

    N = length(ifd)
    O == UInt32 ? write(tf, UInt16(N)) : write(tf, UInt64(N))

    # keep track of which tags are too large to fit in the IFD slot and need a
    # remote location for their data
    remotedata = Vector{Pair{Tag, Vector{Int}}}()
    sorted_keys = sort(collect(keys(ifd)))
    for k in sorted_keys
        tags = ifd[Iterable(k)]
        for tag in tags
            pos = position(tf.io)
            if !write(tf, tag)
                push!(remotedata, tag => [pos])
            end
        end
    end

    # end position, write a zero by default, but this should be updated if any
    # more IFDs are written
    ifd_end_pos = position(tf.io)
    write(tf, O(0))

    for (tag, poses) in remotedata
        tag = tag::Tag
        data_pos = position(tf.io)
        data = tag.data
        # add NUL terminator to the end of Strings that don't have it already
        if eltype(tag) === String
            data = data::SubString{String}
            if !endswith(data, '\0')
                data *= '\0'
            end
            write(tf, data)  # compile-time dispatch
        else
            write(tf, data)  # run-time dispatch
        end
        push!(poses, data_pos)
    end

    for (tag, poses) in remotedata
        tag = tag::Tag
        orig_pos, data_pos = poses
        seek(tf, orig_pos)
        write(tf, tag, data_pos)
    end

    seek(tf, ifd_end_pos)

    return ifd_end_pos
end

function reverse_prediction!(tfs::TiffFileStrip{O}, arr::AbstractArray{T,N}) where {O, T, N}
    pred::Int = predictor(tfs.ifd)
    # for planar data, each row of data represents a single channel
    spp::Int = isplanar(tfs.ifd) ? 1 : nsamples(tfs.ifd)
    if pred == 2
        columns = istiled(tfs.ifd) ? tilecols(tfs.ifd) : ncols(tfs.ifd)
        rows = istiled(tfs.ifd) ? tilerows(tfs.ifd) : cld(length(arr), columns * spp)

        GC.@preserve arr begin
            # horizontal differencing
            temp::Ptr{T} = pointer(arr)
            for row in 1:rows
                start = (row - 1) * columns * spp
                for plane in 1:spp
                    previous::T = unsafe_load(temp, start + plane)
                    for i in (spp + plane):spp:(columns - 1) * spp + plane
                        current = unsafe_load(temp, start + i) + previous
                        unsafe_store!(temp, current, start + i)
                        previous = current
                    end
                end
            end
        end
    end
end

deplane(arr::AbstractVector, n::Integer) = deplane_simd(arr, Val(n))

# {AAA...BBB...CCC...} => {ABCABCABC...}
function deplane_slow(arr::AbstractVector{T}, n) where T
    @debug "rearranging planar data"
    reshape(arr, fld(length(arr), n), n)'[:]
end

# {AAA...BBB...CCC...} => {ABCABCABC...}
@generated function deplane_simd(arr::AbstractVector{T}, ::Val{N}) where {T, N}
    width = cld(sizeof(T) * N, 64) * 64
    count = fld(width, sizeof(T) * N) # pixels per iteration

    sym(x) = Symbol("q", x)

    # vload {AAA...}
    # vload {BBB...}
    # ...
    loads = map(x -> :($(sym(x + 1)) = vload(Vec{$count * $(max(1, x)), T}, ptrA + (index + num_pixels * $x - 1) * $(sizeof(T)))), 0:N-1)

    # shuffle1 = {0, X, 1, X+1, ...}
    # shuffle2 = {0, 1, X, 2, 3, X+1, ...}
    # ...
    perms = []
    for k in 1:N-1
        left = count * k # number of elements in the first shuffle vector (see below)
        # take `k` elements from the first vector, followed by one from the second vector, repeated `count` times
        shuffle::Vector{Int} = mapreduce(x -> vcat(x...), vcat, zip(collect.(partition(0:left-1,k)), left:left+count-1))
        push!(perms, :($(Symbol("shuffle", k)) = $(Val(Tuple(shuffle)))))
    end

    # shufflevector {AAA...}, {BBB...}, shuffle1 => {ABABAB...}
    # shufflevector {ABABAB...}, {CCC...}, shuffle2 => {ABCABCABC...}
    # ...
    shuffles::Vector{Expr} = []
    ll, rr = sym(1), 1
    for x in 1:N-1
        input1 = ll
        ll = sym(x + N)
        input2 = sym(rr += 1)
        push!(shuffles, :($ll = shufflevector($input1, $input2, $(Symbol("shuffle", x)))))
    end
    push!(shuffles, :(final = $ll))

    # assignments for each channel in the final loop
    finish = map(x -> :(out[start + i * $N + $x] = arr[iterations * $count + i + num_pixels * $x + 1]), 0:N-1)

    quote
        @debug "rearranging planar data (SIMD)"

        GC.@preserve arr begin
            ptrA = pointer(arr)
            out = Vector{T}(undef, length(arr) + $count)
            num_pixels = fld(length(arr), N)
            iterations = fld(num_pixels, $count) - 1
            out_index = 1 # output index

            $(perms...)

            @inbounds for index in 1:$count:iterations*$count
                $(loads...)
                $(shuffles...)

                vstore(final, out, out_index)

                out_index += $count * N
            end

            remaining = num_pixels - iterations * $count
            start = iterations * $count * N + 1

            @inbounds for i in 0:remaining-1
                $(finish...)
            end

            resize!(out, length(out) - $count)
        end
    end
end