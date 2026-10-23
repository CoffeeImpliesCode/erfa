# Fork notes

## Upstream-file deviations

No upstream `.c` or `.h` files are modified.

| File | Change | Reason |
|---|---|---|
| `.gitignore` | Retains the 24 upstream patterns, then adds `!/m4/`, `!/m4/erfa-numver.m4` and six Zig-output ignore patterns; it is omitted from `UPSTREAM.sha256`. | Keep the version-macro source trackable and ignore generated build output without changing the recorded upstream files. |

## Build graph

- The build compiles the 249 upstream C translation units directly; it runs neither autotools nor Meson and downloads no source.
- It generates `config.h` in the build cache from upstream's `2.0.1` package version and `20231011` SOFA version. `HAVE_CONFIG_H` and the generated include directory reach both C compilation and header translation.
- `zig/translate.h` is the translation input for all four public headers. Non-NetBSD targets use Aro preprocessing; NetBSD targets run the target compiler's `zig cc -E -dD` first so Aro receives expanded declarations and preserved macros.
- `zig/translate.h` defines `__int128_t` and `__uint128_t` under `__SIZEOF_INT128__` for target headers that name the compiler-provided types.
- In-tree Zig test and executable roots set `.use_llvm = true` for the wide C ABI calls. External Zig consumer roots must set it too; a module cannot select a consumer's backend.
- `-Dlinkage` defaults to static. Dynamic linkage builds a PIC shared library with upstream's ABI version tuple `(9, 1, 8)` and versioned soname.
- `-Druntime=true` changes facade dispatch to an explicitly loaded provider and is independent of linkage; the build still produces and installs its native library.
- Installation includes a relocatable `lib/pkgconfig/erfa.pc`, licence records under `share/licenses/erfa/`, and upstream documentation under `share/doc/erfa/`.
- The build has no system-library integration mode; it compiles the bundled C sources.

## Platform boundaries

- NetBSD's `math.h` expands `__END_DECLS` through `_Pragma`, which Aro cannot parse as C. The target-preprocessor route handles this; AArch64 NetBSD also needs the guarded 128-bit typedefs above.
- WASI has no dynamic linker, so `-Dlinkage=dynamic` is rejected for `wasm32-wasi`; static linkage remains available.
- Upstream's `ERFA_THREAD_LOCAL` chain can resolve to an empty definition, making leap-second state process-global. The build pins neither a C dialect nor this macro, so the selected branch is target-dependent; the `wasm32-wasi` branch is not established here.
- No explicit Windows export list is provided; DLL exports depend on the toolchain's default visibility behavior.
