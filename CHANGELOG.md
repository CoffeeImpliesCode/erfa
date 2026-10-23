# Changelog

- Port to Zig 0.17.0.
- `gnomonic.fromStandardCoordinates` and `fromVector` report the number of useful solutions; `TporsResult` and `TporvResult` name the solutions.
- Provider documentation no longer promises thread-local leap-second state; the selected C compiler's TLS support determines it.
- `load` examples use the shared-library SONAME `liberfa.so.1`.
- Consumer run steps forward `--provider <path>` to the consumer program.
- `devenv` tasks run from the SDK root and use external cache and install directories; install tasks require exported location variables.
- `vectors.s2xpv` returns `Pv` with separate position and velocity vectors, matching upstream's six-value output.
- The typed facade covers 197 C routines across 18 namespaces; remaining declarations stay reachable through `c`.
- The typed facade corrects `cal2jd` status handling, names the equation of origins, returns only written `apio13` fields, and documents upstream units, epochs, leap-table and partial-output contracts.
- `-Druntime=true` routes facade calls through a loaded provider while still building and installing the library.
- `-Dlinkage=static|dynamic` selects a static or shared library; dynamic builds use upstream's ABI version and refuse targets without a dynamic linker.
- `zig build install` writes a relocatable `erfa.pc` and installs licence and documentation records.
- Nix exposes static and shared package outputs with Zig 0.17.0; the devenv shell contains tools only.
- Fork-authored files carry the package owner's BSD-3-Clause grant.
- `README.md` documents the package; upstream's README is retained as `README.upstream.md`.
- NetBSD C translation uses the target compiler's preprocessor and declares its builtin 128-bit integer types for `translate-c`.
- Zig executable and test roots that call the C API must set `.use_llvm = true` for correct `eraApco13` status values.
- The build generates upstream's five-value `config.h` input for C compilation and translation.
