# ERFA

ERFA provides the IAU's Essential Routines for Fundamental Astronomy.
This Zig 0.17.0 package builds `liberfa/erfa` at commit `1a8044cde5b7763295d472a6443387239127c6c8` (ERFA 2.0.1, SOFA base 20231011); package version `2.0.1-dev.1a8044cd`.

## Source deviations

No upstream `.c` or `.h` file is changed. `.gitignore` is the only modified upstream file: it preserves the upstream patterns, includes `m4/erfa-numver.m4`, and ignores Zig build outputs. `README.upstream.md` preserves upstream's `README.rst`.

## Build deviations

The build compiles upstream's 249 C translation units directly. It does not run autotools, Make, Meson, or downloads. It generates `config.h` from upstream's version values.

NetBSD uses its target C preprocessor for aggregate-header translation. `zig/translate.h` declares the compiler's `__int128_t` and `__uint128_t` names when `__SIZEOF_INT128__` is available.

Every Zig executable or test root that imports the module must select LLVM with `.use_llvm = true` (or `-fllvm`). The build installs a relocatable `erfa.pc` file and the package's licence and documentation records.

## Support matrix

| Build path | Target set |
|---|---|
| `zig build check` | Compile-only: `x86_64-linux-gnu`, `aarch64-linux-gnu`, `aarch64-macos-none`, `x86_64-windows-gnu`, `riscv64-linux-gnu`, `wasm32-wasi` |
| `cross-test` | Zig 0.17.0 Tier 1/2 matrix: 53 targets. Runtime execution depends on an available executor; build-only coverage is not runtime coverage. |

## Consumption

Fetch the GitHub dependency into the consumer's `build.zig.zon`:

```sh
zig fetch --save git+https://github.com/CoffeeImpliesCode/erfa#v2.0.1-dev.1a8044cd
```

Import the `erfa` module in the consumer's build graph. The module links the native library for the linked configuration.

```zig
const dep = b.dependency("erfa", .{ .target = target, .optimize = optimize });
mod.addImport("erfa", dep.module("erfa"));
```

The C library artifact is named `erfa` and installs as `liberfa.a` by default. Dynamic linkage installs the shared library with upstream ABI version `(9, 1, 8)`. C consumers use `erfa.h`, `erfam.h`, `erfaextra.h`, and `erfadatextra.h`; `erfa.h` does not include `erfam.h`. `libm` is the only C link dependency.

| Option | Default | Effect |
|---|---|---|
| `-Dlinkage=static` | Yes | Build and install the static archive. |
| `-Dlinkage=dynamic` | No | Build and install a shared library. Refused on `wasm32-wasi`. |
| `-Druntime=true` | No | Dispatch calls through an explicitly loaded provider; independent of linkage, and the package library is still built and installed. |

Runtime loading accepts either an explicit file path or a system-loader name. See `README.zig.md` for the loader API.
