# cross-test settings profile for erfa.
#
# `cross-test` looks for this file at the root of the project it is run from
# (or names it with --profile; --no-profile ignores it). It is trusted Bash that
# the harness `source`s, so this file is *settings only*: ordinary variable
# assignments and nothing else. No command runs, no compiler is probed, and no
# path in here names a host.
#
# There is deliberately no CROSS_MATRIX. The published 53-platform Zig 0.16
# Tier 1/2 table is the matrix this package is checked against, and a matrix
# named here would replace it. There is no TARGETS array either, for the same
# reason: a subset selected here would narrow the run rather than add to it.
# Both belong on the command line, where --targets selects from the active
# matrix and never adds to it.
#
# CROSS_BUILD_STEP stays the standard `test` step, which is what this profile
# states explicitly. There are no `cross_build_command` / `cross_artifact`
# hooks here, so the harness keeps its standard Zig-build mode and runs
# `zig build test -Dtarget=TARGET` per target with a fresh cache. What that
# means for a given target is the harness's decision, not this package's: a
# host target runs, a foreign target runs under whatever executor the harness
# detects (QEMU user mode, Wine, wasmtime), and a foreign target with no
# executor is reported as build-only coverage -- compiled, never executed, and
# never counted as a pass. `build.zig` gives the test binary and the facade
# exercise a Run step for every target, which is what leaves that choice open.
#
# A target graph compiles all 249 core ERFA translation units, translates the
# four public headers, and compiles the facade, the exercise, the tests and the
# smoke example alongside them. That is a large graph for one cache directory,
# so the build jobs are held at four and the deadlines are generous: the
# per-target wall clock on this tree is dominated by C compilation, and a
# deadline that expires mid-target reports a timeout rather than a result.
#
# `upstream-test` (upstream's own t_erfa_c and t_erfa_c_extra) is a separate
# step and is not named here. Those are two self-contained C programs with no
# fixture, and running them per target through the standard test step would add
# two more processes to every cell without adding coverage the Zig suite does
# not already have.
#
# Linkage is not named here. This profile runs the package's default graph,
# which is the static archive -- the delivery `zig build` produced before
# `-Dlinkage` existed and the one every gate in this repository's recorded
# history observed. A shared-artefact matrix is the same run with
# `-Dlinkage=dynamic` supplied by whoever runs it, through the harness's own
# build-argument setting; hard-coding one linkage here would silently narrow
# the other out.
#
# A target whose OS has no dynamic linker -- WASI, whose
# `std.Target.DynamicLinker.kind` is `.none` -- is in scope for that default
# matrix, because an archive is buildable there. It is not in scope for a
# shared-artefact one: `build.zig` refuses `-Dlinkage=dynamic` for a target that
# cannot carry a shared object rather than answering with a different artefact,
# so a shared run over the full published table fails on those cells by design.
# Whoever asks for the shared matrix decides whether to exclude them.

CROSS_BUILD_STEP=test
CROSS_BUILD_JOBS=4
CROSS_BUILD_TIMEOUT=3600
CROSS_TIMEOUT=1800