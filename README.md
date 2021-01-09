# 💎 TiffImages.jl

| **Stable release** | **Documentation**                 | **Build Status**                                              |
|:------------------------------------------------------|:-------------------------------------------------------------------------|:--------------------------------------------------------------|
| ![](https://juliahub.com/docs/TiffImages/version.svg) | [![][docs-stable-img]][docs-stable-url][![][docs-dev-img]][docs-dev-url] | [![][status-img]][status-url] [![][travis-img]][travis-url] [![][codecov-img]][codecov-url] |

This package aims to be a fast, minimal, and correct TIFF reader and writer
written in Julia.

## Features

- Fast reading and writing of many common TIFFs
- Extensible core for other TIFF packages to build on
- Native integration with `Colors.jl` and the Julia Array ecosystem
- Memory-mapping for loading images too large to fit in memory
- Support for BigTIFFs for large images

## Installation

`TiffImages.jl` is available through Julia's general repository. You can install
it by running the following commands in the Julia REPL:

```julia
using Pkg
Pkg.install("TiffImages")
```

Please see the documentation above for usage details and examples

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://tamasnagy.com/TiffImages.jl/stable

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://tamasnagy.com/TiffImages.jl/dev

[travis-img]: https://travis-ci.com/tlnagy/TiffImages.jl.svg?branch=master
[travis-url]: https://travis-ci.com/tlnagy/TiffImages.jl

[codecov-img]: https://codecov.io/gh/tlnagy/TiffImages.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/tlnagy/TiffImages.jl

[status-img]: https://www.repostatus.org/badges/latest/active.svg
[status-url]: https://www.repostatus.org/#active
