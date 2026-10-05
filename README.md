# ERFA — Zig 0.16 SDK

ERFA is the IAU's *Essential Routines for Fundamental Astronomy*: C routines for
astronomical timescales, leap seconds, precession and nutation, frame
rotations, ICRS-to-observed transformations, analytical Earth/Moon/planet
ephemerides, and the vector, matrix and spherical algebra those need.

This repository is that library packaged for Zig 0.16: the pinned upstream tree
(`liberfa/erfa` at `1a8044cde5b7763295d472a6443387239127c6c8`, package version
`2.0.1`, SOFA base `20231011`, published as `2.0.1-dev.1a8044cd`), all **249**
core translation units and the **4** public headers compiled directly from this
tree, a complete raw C route, a bounded typed facade, tests, upstream's own two
validation programs, and standalone `package.nix` / `flake.nix` / `devenv`
packaging.

Status vocabulary is `foundation-libs/AGENTS.md` §2. **No build, test, smoke
run, cross-target check, formatter, linter, compiler probe, `zig`, `nix` or
`devenv` invocation and no `git` command was run to produce this file.** Every
statement is a read-out of a file in this tree or a quotation of a receipt.

Records: `README.zig.md` (Zig interface, gate record), `UPSTREAM.md` (pin,
re-pinning procedure, source structure), `NOTICE.md` (per-file licence
inventory), `FORK-LICENSE.md` (grant for this fork's files), `CHANGELOG.md`
(numbered fork-only history), `FORK-NOTES.md` (problems and fixes),
`README.upstream.md` (upstream's `README.rst`, byte-for-byte).

---

## 1. Current native-source deviations

**None.** No `.c` and no `.h` file is patched. The pinned commit's 269 regular
files were compared against a pristine import and the only reported difference is
`.gitignore` (`local://foundation-matrix-source-integrity.json`,
`native_upstream.erfa`: `files_checked: 269`, `differences: [".gitignore"]`).

`.gitignore` is a recorded deviation, not a silent edit: all 24 of upstream's
patterns are present verbatim and in their original order, and this fork appends
only `!/m4/`, `!/m4/erfa-numver.m4` and six Zig build-output patterns. It is
deliberately absent from `UPSTREAM.sha256` so that `sha256sum -c` fails on the
edit rather than hiding it (`CHANGELOG.md` 7, `FORK-NOTES.md` 13,
`NOTICE.md` §4).

Two upstream facts that a caller inherits unchanged and would otherwise mistake
for fork behaviour: `src/dat.c:126` carries `enum { IYV = 2023 }` and
`src/dat.c:242` the test `if (iy > IYV + 5) j = 1;`, so **every call with a year
of 2029 or later returns upstream's *dubious year* warning `+1` while still
computing the value**; and the table's last entry is 2017-01-01 at ΔAT = 37.0 s
(`src/dat.c:192`).

## 2. Current native-build deviations

Upstream builds with autotools and meson. This package builds neither: it never
runs `bootstrap.sh`, `autoreconf`, `configure`, `make` or `meson`, and downloads
nothing. Upstream's own build files are retained and digested as material, never
executed.

| # | Deviation | Where |
|---|---|---|
| D1 | The 249 translation units come from `liberfa_la_SOURCES` (`src/Makefile.am:2-35`), cross-checked name-for-name and in the same order against `src/meson.build:6-39` | `build.zig` |
| D2 | `config.h` is written from five recorded values — `PACKAGE_VERSION "2.0.1"`, `_MAJOR 2`, `_MINOR 0`, `_MICRO 1`, `SOFA_VERSION "20231011"` — with `HAVE_CONFIG_H` defined and the generated directory on **both** the compile line and the translation line, because `src/erfaversion.c:16` includes it by bare name | `build.zig` |
| D3 | `.use_llvm = true` on every Zig test/executable root that imports this module (§4.1) | `build.zig`, `consumer/build.zig` |
| D4 | On NetBSD targets the aggregate header is preprocessed by the target's own `zig cc -E -dD` before `translate-c` parses it, because NetBSD's `cdefs.h` routes `__END_DECLS` through `_Pragma` framing that Aro hands to the parser as C. The condition is the OS tag, not a triple list | `build.zig`, `zig/translate.h` |
| D5 | Under the compiler's own `__SIZEOF_INT128__`, `zig/translate.h` restates `__int128_t`/`__uint128_t`, which `generic-netbsd/arm/cdefs.h:62-63` names without any header declaring them. A compiler builtin is restated; no upstream declaration is touched | `zig/translate.h` |
| D6 | `-Dlinkage=static\|dynamic` selects the artefact kind. The **default is `.static`**, and it is a no-op rather than a change: the static path passes `pic = null`, which emits no `-fPIC`/`-fno-PIC` at all. The shared object carries upstream's own libtool ABI version `(9, 1, 8)` (`configure.ac:20`) with a soname and version links. A target whose OS has no dynamic linker — `wasm32-wasi` — **refuses** `-Dlinkage=dynamic` rather than answering with an archive, because a caller who asked for a shared object did not ask for a different artefact | `build.zig` |
| D7 | `lib/pkgconfig/erfa.pc`, `share/licenses/erfa/` and `share/doc/erfa/` are rendered and installed by the build graph, not the packaging. `addPkgConfig` substitutes upstream's `erfa.pc.in` — its field names, order and `Name:`/`Description:`/`Libs:` spellings — with `@prefix@` as `${pcfiledir}/../..`, so the installed file is **relocatable** | `build.zig` |
| D8 | `.gitignore` append (§1) | `.gitignore` |
| D9 | `-Druntime` switches the **dispatch**, not the artefact, and is orthogonal to `-Dlinkage`: `addGraph` imports `c` from `runtime_graph.createModule(...)`, drops `module.linkLibrary(c_lib)`, and the **linked** branch instead imports `rt` from `createCoreModule(...)`. The library is still built and installed either way. Default off | `build.zig`, `runtime/` |

**History.** `CHANGELOG.md` is append-only and numbered. Entries 1–10 predate
this migration and each names its own receipt; entries 11–14 were written on
2026-10-04 for it and are `PENDING-VERIFICATION`. The problems behind them, with
condition, symptom and fix, are `FORK-NOTES.md` 1–22.

## 3. Build, run and test matrix

### 3.1 Commands

```
zig build                                 # 249 TUs, translation, facade, exercise,
                                          # smoke; installs artefact, 4 headers,
                                          # erfa.pc, licence/doc records, LICENSE, INFO
zig build test                            # 60 behavioural tests + the facade exercise
zig build smoke | consumer | upstream-test
zig build check                           # six-target compile matrix; runs nothing
zig build install --prefix DIR
zig build install -Dlinkage=dynamic --prefix DIR
zig build -Druntime=true

devenv shell                              # canonical; does not build the library
devenv build outputs.static               # the SDK's own linkage policy
devenv build outputs.shared               # -Dlinkage=dynamic
devenv tasks                              # sdk:build, sdk:test, sdk:check, ...
devenv tasks run sdk:licence              # integrity: the 268 UPSTREAM.sha256 records
devenv tasks run sdk:consumer             # the module consumer
devenv tasks run sdk:shared-install       # shared install, prefix outside this tree

nix build .#default | .#static | .#shared
```

`zig build` compiles the smoke example and the facade exercise but installs
neither: "compiled" and "installed" are different claims here
(`README.zig.md` §9c). `nix develop` is a convenience; devenv is canonical.

**Every task runs against this checkout.** devenv materialises a task as a
generated program that starts in the directory the caller was in, so each `exec`
in `devenv.nix` changes to this SDK's own directory before it runs anything. That
directory is named in `devenv.nix` as `builtins.toString ./.`, read out of the file
that declares it — not taken from `$DEVENV_ROOT`, which is the devenv *project*
directory and holds no `build.zig`, no `UPSTREAM.sha256` and no `consumer/`. A
scratch project the caller chose therefore never stands in for the source, and
`devenv --from path:…/erfa tasks run sdk:consumer` builds this tree from any
working directory.

**The installing tasks write outside the tree.** Two of the tasks install, and
`zig build`'s own default prefix is `zig-out/` **inside the checkout**:
`sdk:build`, because `build.zig` puts the artefact, the four headers, `erfa.pc`
and the licence/doc records on the default step, and `sdk:shared-install`. Each
resolves its own `--prefix` from **exported** values only — `sdk:build` from
`$ERFA_INSTALL_PREFIX`, else `$ZIG_LOCAL_CACHE_DIR/erfa/build`, else
`$TMPDIR/erfa/build`; `sdk:shared-install` from `$ERFA_INSTALL`, else
`$ZIG_LOCAL_CACHE_DIR/erfa/shared`, else `$TMPDIR/erfa/shared`. No branch of
either chain is inside the repository. **With none of the three exported there
is no default at all**: the task names what to export on stderr and exits
non-zero rather than picking a location this file does not get to invent — there
is no `/tmp` fallback and no host path in these files. Nothing here unsets a
variable: an exported value is used as it is, and `zig build`'s own cache is
named explicitly, to that same directory, by the `--cache-dir` every route
carries. `sdk:test`, `sdk:smoke`, `sdk:consumer`, `sdk:upstream-test` and
`sdk:check` do not depend on the install step and are given no prefix.

**Every task's `zig build` names `-j8`, `--summary all` and an external cache.**
That is the workspace's per-library recipe (`foundation-libs/AGENTS.md`:157-158),
and a task cannot be handed any of it from outside: `devenv tasks run` takes no
trailing arguments, so nothing appends a job count, a cache or a summary after
`devenv.nix` has been evaluated. Each of the seven `zig build` routes therefore
writes them itself —
`zig build [step] --cache-dir "$ZIG_LOCAL_CACHE_DIR/erfa/cache" [--prefix …]
[-D…] -j8 --summary all` — after a preamble that changes into this checkout and
then **completes** an unset `$ZIG_LOCAL_CACHE_DIR` / `$ZIG_GLOBAL_CACHE_DIR` from
`$XDG_CACHE_HOME` and then `$TMPDIR`, never overwriting one the caller exported;
with none of the four named the task prints on stderr and exits non-zero rather
than letting `zig build` write `.zig-cache` into this checkout. The fill is in
the task body and not only in `enterShell`, because `devenv tasks run --mode
single` starts a generated program that never sources the shell hook. The two
tasks that run no build at all — `sdk:licence` and `sdk:fmt` — carry none of it.

### 3.2 Observed before this migration

Driver runs of 2026-10-03, against the tree as it stood before entries 11–14
landed. Full table with commands, modes, targets, exit codes and receipts:
`README.zig.md` §9a. **The migrated tree is covered by §3.2b, not by this
table.**

| Gate | Command (abbreviated) | Mode / target | Exit | Receipt |
|---|---|---|---:|---|
| install + tests + exercise + smoke + consumer + upstream validation | `zig build install test smoke consumer upstream-test --prefix …/install` | Debug / native | 0 | `local://foundation-matrix-erfa-current-debug-r1.log` — `24/24 steps`, `51/51 tests` |
| the same, without `install` | `zig build test smoke consumer upstream-test` | ReleaseSafe / native | 0 | `…-releasesafe-native.log` — `20/20 steps`, `51/51 tests` |
| tests + exercise + smoke + consumer | `zig build test smoke consumer` | ReleaseFast / native | 0 | `…-releasefast-native.log` — `15/15 steps`, `51/51 tests` |
| tests + exercise + smoke + consumer | `zig build test smoke consumer` | ReleaseSmall / native | 0 | `…-releasesmall-native.log` — `15/15 steps`, `51/51 tests` |
| six-target compile matrix | `zig build check` | default / 6 targets | 0 | `…-six-baseline.log` — `55/55 steps` |
| NetBSD translation | `zig build check -Dtarget=aarch64-netbsd` | default / `aarch64-netbsd` | 0 | `…-netbsd-preprocess-check-r2.log` — `11/11 steps` |
| 53-platform matrix | `cross-test` | default / 53 targets | 0 | `…-cross-corrected-summary.json`, run `20261003-194646-57707-28197` — `pass 20, fail 0, build_only 33` |
| installed C consumer, compile + run | `zig cc -std=c99 -I …/install/include … -lerfa -lm` | native | 0 | `…-installed-c-current-compile.log`, `-run.log` |
| provenance digests | `sha256sum -c UPSTREAM.sha256` | n/a | 0 | `…-provenance-checksums.log` — 268 files, every line `OK` |
| backend discriminator | two probe builds differing only by `-fllvm` | Debug / native | 0 / 0 | `…-boundary-isolation.log`, `…-boundary-llvm-discriminator.log` |

What those rows do not say, as their own receipts state: the 53-platform run's
status is `partial` with `exit_code 0` — 20 targets executed all 51 tests, **33
built and never ran**, including all nine NetBSD targets and `wasm32-wasi`; the
two `check` rows **run nothing**; the installed-C program is the installed-C
job's own C source, compiled and run by the driver outside CI, so the workflow
itself was never executed and no CI result is claimed either way; and the package
round trip is recorded outside this repository in
`local://foundation-matrix-final-package-proof.json`, which nothing here asserts
an outcome for.

### 3.2b Observed against the migrated tree

The migration grew the typed route from 99 members to 197 and `tests.zig` from
51 tests to 60, so the table above describes a different tree. These rows are
the current evidence, each scoped to what its own receipt prints. Commands,
modes and the reading of each row are in `README.zig.md` §9a.2.

| Gate | Mode / target | Exit | Receipt |
|---|---|---:|---|
| full SDK suite + facade exercise + smoke | Debug / native, linked, static | 0 | `local://foundation-contract-erfa-current-full-gate-after-aberration-and-spin-repair.log` — `12/12 steps`, `60/60 tests` |
| consumer program | Debug / native, linked | 0 | `local://foundation-contract-erfa-consumer-linked-run.log` — `7/7 steps`, `consumer: every checked value matched` |
| upstream validation programs | Debug / native, linked | 0 | `local://foundation-contract-erfa-linked-single-output-corrected-smoke-and-full-facade-test.log` — both programs print `validation successful` |
| `-Dlinkage=dynamic` install | Debug / native | 0 | `local://foundation-contract-erfa-native-shared-unused-foreign-refusal-graph-fixed-build.log` — `19/19 steps`, `install success` |
| runtime-loaded smoke, provider named by path | Debug / native, `-Druntime=true` | 0 | `local://foundation-contract-erfa-current-canonical-real-runtime-static-smoke-after-leap-table-invariant-fix.log` — `7/7 steps`, `smoke: every checked value matched` |
| every recorded upstream byte | n/a | 0 | `local://foundation-contract-erfa-all-recorded-native-upstream-bytes-integrity.log` — 268 lines, every line `: OK` |

### 3.2c Observed on the current graph — the source-bound cohort

Four driver gates ran against the graph as it now stands. The 53-cell cohort is
the source-bound one: its receipt records
`source_stamp_before == source_stamp_after` (`a4ed8e98…`) with `target_jobs 8`,
`jobs_per_build 8`, `zig_version 0.16.0`, `mode zig-build` and `target_count 53`.

| Gate | Mode / route | Exit | Receipt |
|---|---|---:|---|
| native eight cells — `zig build test smoke install`, static × dynamic crossed with Debug, ReleaseSafe, ReleaseFast, ReleaseSmall, `-Druntime=false` | native, linked | 0 in all eight | `native-final-evidence/20261004T233628757747Z-69351/run.json` — `Build Summary: 25/25 steps succeeded; 61/61 tests passed` |
| own-loaded eight cells — the same eight configurations with `-Druntime=true` and `ERFA_TEST_PROVIDER` naming this tree's own `liberfa.so.1.8.1` (`provider.kind: "own"`) | native, loaded | 0 in all eight | `loaded-final-evidence/20261004T232823091897Z-23133/run.json` — `Build Summary: 26/26 steps succeeded; 61/61 tests passed` |
| 53-cell `cross-test` | default optimize / 53 targets | **0**, `status: partial` | `20261004T221720228710Z-45046/erfa-53-target-8.json` — `pass 20, fail 0, build_only 33, partial 0`; every executed cell reports `tests=61` |
| compile-only `zig build check` baseline, six triples | default / 6 targets | 0 | `baselines-and-configs/20261005T014547Z-797a73f2`, row `baseline-erfa-check` — `Build Summary: 55/55 steps succeeded`, `declared_target_count 6`, all six named, `test_pass_lines: []` |

**`build_only` is not a pass, and 33 of the 53 cells are in it.** Those cells
compiled and ran nothing because no executor was available — which includes all
nine NetBSD targets and `wasm32-wasi`. The 20 executed cells are the whole of the
runtime evidence in that table, and each of them ran 61 tests.

**The counts above describe that epoch and nothing later.** An edit to this
graph, its helpers or its generated headers that landed after
`20261004T221720228710Z-45046` is not covered by them. The `check` baseline is
compile-only by construction and by the receipt's own
`runtime_pass_claimed: false`; it runs nothing and derives no runtime result.

**What §3.2b said that this supersedes.** §3.2b reports `60/60 tests` on a tree
whose suite has since grown to 61, so those six rows describe a slightly earlier
tree and stay in this file as history. Two claims in §3.2b are no longer current
and are corrected here: the surface is now observed in **all four** optimize
modes rather than `Debug` alone, and it **does** have a 53-platform matrix, the
one above. What is still open is unchanged in kind: the runtime route is now
observed as a full `test smoke install` in all four runtime/linkage combinations
against one explicitly named provider, not as a smoke program alone, but the
consumer-behaviour checks are still owed; and the Windows `DEF` export list is
still unexercised. Nothing in this SDK is complete, and no row above may be read
as saying so.

### 3.3 Pending verification

Each row is what the gate still needs. Where §3.2b has observed part of an item
the row says so and names what is left; where it has observed nothing, the row
is the driver's check and not a result.

| Item | Needs |
|---|---|
| `-Dlinkage=static` and `-Dlinkage=dynamic` both build and install (D6), in `Debug` | **done in `Debug` for both** (§3.2b) and now in **all four** optimize modes for both linkages (§3.2c) |
| The shared object exports the whole `era*` surface, carries ABI `(9, 1, 8)` with a working soname, and links against libm at run time | the export count and soname are read off the installed file (§3.2b) and the shared object is what the own-loaded cells loaded by name (§3.2c); what is still owed is an installed-C consumer **linked and run** against `lib/liberfa.so`, and any Windows `DEF` list |
| `check -Dlinkage=dynamic` walks the shared artefact | the six triples; the compile-only baseline above walked the default static selection |
| `erfa.pc` is installed, relocatable, and usable from a moved tree | the file is installed with `prefix=${pcfiledir}/../..` (§3.2b); `pkg-config --cflags --libs erfa` from a moved tree is still owed |
| `package.nix` static and shared derivations produce exactly the layout `zig build install` writes | `nix build .#static`, `nix build .#shared`, output-layout inspection, `nix-store --query --references` |
| `devenv shell` enters without building, and the two `outputs` realise | `devenv build outputs.static`, `outputs.shared` |
| Every `devenv` task locates this checkout itself, `sdk:build`/`sdk:shared-install` install outside it, and every `zig build` route runs `-j8 --summary all` against an external `--cache-dir` (§3.1) | **not observed since the change, nor since `CHANGELOG.md` 18.** The two gates that motivated it are `devenv tasks run --mode single sdk:consumer` and `sdk:licence` from a scratch project cwd (`CHANGELOG.md` 17); `sdk:build` and `sdk:shared-install` have not been run at all. No row in §3.2b covers them |
| `flake.lock` and `devenv.lock` exist with recorded narHash | `nix flake lock`, `devenv lock`; the driver writes both |
| `-Druntime=true` builds, links against no native artefact, still installs the library, and leaves a linked build unchanged (D9) | the driver-owned runtime core is in `runtime/`; a smoke run against an explicitly named provider passed (§3.2b) and all four runtime/linkage combinations now run `test smoke install` against this tree's own `liberfa.so.1.8.1` (§3.2c). Still owed: the `consumer` and `upstream-test` steps under `-Druntime=true`, and a diff of that build against the option-off build |
| `load` behaviour: explicit path vs named-system source, no fallback, atomic publication, explicit retry after failure, idempotence, rejection of a changed request after READY, pre-initialization panic in ReleaseFast and ReleaseSmall | the consumer-behaviour checks; only the provider-layout refusal has been observed (§4.5) |
| Every §3.2 row re-run against the migrated tree | `test smoke install` and the six-target `check` baseline are re-run in §3.2c; the `consumer` and `upstream-test` rows of §3.2b are still the §3.2b receipts |

### 3.4 Boundaries that are real

- **`wasm32-wasi` and the TLS chain.** `ERFA_THREAD_LOCAL`
  (`src/erfadatextra.h:38-50`) resolves through five branches and can resolve to
  nothing. `wasm32-wasi` builds and is never run, so the chosen spelling was
  *accepted* and which branch was taken is not shown. On the empty branch the
  leap-second state is process-global, with no diagnostic. Open because there is
  no runner, not because anything fails.
- **`aarch64-macos-none`.** The six-target `check` compiles it — library, tests,
  exercise, smoke, both upstream programs — so every header the core and the
  oracle need resolves for the libc-less target. Nothing has run there.
  `aarch64-macos` in the 53-platform table is a *different* target.
- **NetBSD.** All nine NetBSD targets build; none has ever been run.
- **The LLVM defect's cause is unestablished.** §4.1 says what the flag buys and
  where it was measured; no mechanism inside the Zig front end is claimed.
- **Runtime loading is opt-in and off by default.** `-Druntime=true` is the
  route; a linked build is the default and is unchanged.

## 4. Consumption

### 4.1 Consumers must build with LLVM

`.use_llvm = true` on every Zig executable or test root that imports this
package's `erfa` module, or `-fllvm` on the command line.

On 2026-10-03 the driver built one probe twice against **one** archive, changing
nothing but the flag. `eraApco13` — a fourteen-argument call, twelve `double`
scalars and two pointers (`src/erfa.h:80-83`) — returned `1` on a valid 2013
date `2456384.5 + 0.969254051` where `0` is correct, and `1` on an unacceptable
`−1e10 + 0` where `−1` is correct. With `-fllvm` both were right. `eraUtctai`,
in the same probe, was correct either way. `+1` is upstream's *dubious year*
warning, so under the default backend a caller treating non-zero as failure
rejects a good date, and one accepting a positive status accepts `−1e10`. That
is a wrong answer, not a crash. Receipts: `…-boundary-isolation.log`,
`…-boundary-llvm-discriminator.log`. Scope and what is not established:
`README.zig.md` §1a.

A module cannot force a dependent's backend, so the requirement is published
rather than enforced:

```zig
const dep = b.dependency("erfa", .{ .target = target, .optimize = optimize });
const mod = b.createModule(.{ .root_source_file = b.path("src/main.zig"),
                              .target = target, .optimize = optimize });
mod.addImport("erfa", dep.module("erfa"));
const exe = b.addExecutable(.{ .use_llvm = true,          // REQUIRED; see 4.1
                               .name = "my-erfa-consumer", .root_module = mod });
```

The requirement is on **Zig** roots only. A C program linking
`liberfa.a`/`liberfa.so` has no Zig root and needs no flag: the installed-C
program in `README.zig.md` §9a is compiled by `zig cc` with no backend flag and
runs.

### 4.2 From Zig

```zig
const erfa = @import("erfa");

pub fn main() void {
    // Two-part dates: the sum is the value, the split is arbitrary.
    const r = erfa.rotation.apco13(
        .{ .part_a = 2456384.5, .part_b = 0.969254051 },
        .{ .delta_ut1 = 0.0, .longitude = 0.0, .latitude = 0.0, .height = 0.0,
           .polar_motion_x = 0.0, .polar_motion_y = 0.0, .pressure = 0.0,
           .temperature = 0.0, .humidity = 0.0, .wavelength = 0.55 },
    );
    // `r.status` is a `Status`, not a Zig error: +1 dubious year, 0 ok, -1
    // unacceptable date. `r.astrom` and `r.equation_of_origins` are null on -1.
    _ = r;
}
```

`README.zig.md` is the Zig interface document: names and entry points, the
complete raw C surface, the bounded typed surface, measured consumer costs, the
two-part-date and UTC traps, the leap-second ownership contract, and the full
gate record.

### 4.3 From C

```
DIR/lib/liberfa.a                       # or liberfa.so + soname/version links
DIR/include/{erfa.h,erfam.h,erfaextra.h,erfadatextra.h}
DIR/lib/pkgconfig/erfa.pc               # relocatable: prefix=${pcfiledir}/../..
DIR/share/licenses/erfa/{LICENSE,INFO,NOTICE.md,FORK-LICENSE.md,UPSTREAM.md}
DIR/share/doc/erfa/{README.upstream.md,README.rst}
DIR/{LICENSE,INFO}
```

Every one of those paths is written by `zig build install` itself; the Nix
derivation adds nothing to the prefix.

`erfa.h` does **not** include `erfam.h` — upstream made that explicit in 2.0.0
(`README.rst:66-68`). A consumer wanting both writes `#include <erfa.h>` and
`#include <erfam.h>`, as `src/t_erfa_c.c:1-2` does.

### 4.4 Leap-second state, and the two bounds a caller must know

`changes` and `NDAT` are file-scope `static ERFA_THREAD_LOCAL`
(`src/erfadatextra.c:22-23`) — internal linkage, so **in no symbol table at
all**. The table is reachable only by calling `eraGetLeapSeconds`,
`eraSetLeapSeconds` or `eraDatini` (`src/erfadatextra.c:26,50,68`). Therefore:

- **Retention is per-thread.** `eraSetLeapSeconds` keeps the caller's pointer
  with no copy and no check — upstream's own note reads "*No* sanity checks are
  performed" (`src/erfadatextra.c:60-65`) — so the caller's storage must stay
  alive and unmodified until the next replacement or reset *on that thread*. On
  the empty `ERFA_THREAD_LOCAL` branch the storage is process-global instead;
  which branch a target takes is §3.4's open question.
- **`eraGetLeapSeconds` has a side effect and can fail.** It initialises lazily
  through `eraDat(2000, 1, 1, 0., &delat)` and returns `-1` if that does not
  return `0` (`src/erfadatextra.c:39-45`).
- **A replacement must be the whole built-in table.** `eraDat` applies the
  pre-1972 drift correction **by table index**, `if (i < NERA1) da += …`
  (`src/dat.c:241-242`, `NERA1 == 14` from the 14-row `drift` table), and
  compares the pre-UTC boundary against `changes[0].iyear` (`src/dat.c:222`). A
  short modern table re-points the drift model and moves that boundary, silently,
  **even when it is correctly sorted**. Upstream's own maintenance procedure is
  the doc block at `src/dat.c:14-42`; a leap-second update is an upstream change
  this package takes by re-pinning and re-measuring, never by hand-editing
  `src/dat.c` (`UPSTREAM.md` §7).

### 4.5 Native ABI families

**The four headers declare 255 functions.** `erfa.h` 247, `erfaextra.h` 7
(`eraVersion`, `eraVersionMajor`, `eraVersionMinor`, `eraVersionMicro`,
`eraSofaVersion`, `eraGetLeapSeconds`, `eraSetLeapSeconds`), `erfadatextra.h` 1
(`eraDatini`); `erfam.h` is 35 macros and no function. Do not confuse 255 with
**249**, the count of core translation units in `src/Makefile.am` — two
different facts that were once conflated in `zig/root.zig` and
`runtime/library.zig` and were corrected on 2026-10-04. No count is hardcoded in
a code path: `runtime/graph.zig` generates the dispatch over what `translate-c`
actually emitted.

| Family | Note |
|---|---|
| `int` status | 46 of `erfa.h`'s 247 return a signed SOFA-style status, and three distinct negative idioms coexist; a facade must not collapse them (`FORK-NOTES.md` 1, 15). Other `int` returns are not statuses: `eraVersionMajor`/`Minor`/`Micro` give `2.0.1`'s components, `eraGetLeapSeconds` a table length or `-1` |
| `double` | angles radians, geodetic height metres, `pmt` Julian years, `epoch` an absolute Julian epoch (`README.zig.md` §3b) |
| `void` + caller out-pointers | partial output differs per routine and is tabulated per result type in `README.zig.md` §3b |
| fixed-size C array parameters | `double pnat[3]`, `double ebpv[2][3]`, `double rb[3][3]`, `eraLDBODY b[]`, `int iymdf[4]`; all decay to pointers |
| `const char *` / `char *` | the `eraD2dtf`/`eraDtf2d` scale is compared with `strcmp`, so it is exactly `"UTC"` (`FORK-NOTES.md` 6) |
| `eraLEAPSECOND **` out-parameter | yields the address of thread-local state; see §4.4 |
| thread-local internal statics | `src/erfadatextra.c:22-23`; not an exported symbol |

**No struct is returned by value** anywhere: `eraASTROM` and `eraLEAPSECOND` are
filled through out-pointers. There are **no variadic functions** and **no
callbacks**.

**Runtime loading.** `-Druntime=true` switches the dispatch, not the artefact,
and is orthogonal to `-Dlinkage`; the library is still built and installed either
way, because a caller may name a provider this tree did not build and may
equally want the one it did. The asymmetry is load-bearing: `LoadSource` and
`LoadError` are this SDK's public types and have to be the *same* types in one
build, so the two branches must not both call `createCoreModule` — a second core
instance would be a second, nominally distinct `LoadSource` that `erfa.load`
could not accept. `zig/root.zig` exports `runtime_loaded`, `LoadSource`,
`LoadError`, `load(source)` and `loadedSource()`.

A consumer reaches the provider explicitly and never by guessing:
`try erfa.load(.{ .path = "/usr/lib/liberfa.so.1" })` before using anything else —
`liberfa.so.1` being the soname this package's own shared object carries
(`README.zig.md` §9a.2). `.path` names a file, `.system` names a library for the
platform loader, and neither falls back to the other; the handle and the
module's own copy of the request live to the end of the process. A call before
the table exists stops the program with a message naming the function, in every
optimization mode.

**A provider is checked before it is used, and the check is about layout.** After
every symbol resolves and before anything is published, `runtime/library.zig`'s
`validate` asks the provider for its own `eraSofaVersion()` and walks its
leap-second table through *this* header's `eraLEAPSECOND` record. A provider that
answers an empty version string, reports no table, returns a null table pointer,
names a month outside 1–12 or a year outside the range `eraDat` accepts, or
returns records that are not sorted by year and month, is **refused with the
reason printed** and `load` returns `ValidationFailed` — nothing is published
and the candidate is closed. That check exists because the leap-second state has
internal linkage and is in no symbol table at all (§4.4): the table can only be
reached by calling through it, so the layout of the record is the one thing a
provider can disagree about silently. It is a layout check, not a version or
correctness test — a provider whose table is well shaped but numerically wrong
passes it.

Nothing about loader *behaviour* beyond that refusal is claimed here as observed;
the rest are §3.3's.

### 4.6 Five things the typed route says about the arithmetic

Stated here because they are consumer-visible and easy to get wrong; each is
argued from source, with its citations, in `README.zig.md` §3d.

- **`vectors.pvxpv(a, a)` is zero in real arithmetic and not necessarily in
  floating point.** `eraPxp` forms each component as a difference of two
  products (`src/pxp.c:43-45`), so a self-cross is `x - x` per component —
  exactly `0.0` — unless the compiler contracts the multiply-add, which leaves
  the rounding error of one product instead. The package's own check is a `1e-14`
  absolute tolerance on that member, and **exact equality is used only where
  upstream's expression cannot round**: `eraPmp` and `eraPpp` are componentwise
  `-` and `+` (`src/pmp.c`, `src/ppp.c`), so `pvmpv(a, a)` is exactly zero and
  `pvppv(a, a)` is exactly doubled.
- **`vectors.pvu(dt, pv)` copies the velocity; it does not scale it**, and
  `vectors.pvup(dt, pv)` may differ from it in the last bit because `eraPvup`
  writes `p + dt*v` in one expression a compiler may fuse while `eraPvu` rounds
  the product first (`src/pvu.c:37-38`, `src/pvup.c:37-39`, `src/ppsp.c`).
  Neither is more correct; compare with a tolerance.
- **`vectors.pap` is a bearing and `vectors.sepp` is a distance.** They take the
  same kinds of argument and answer different questions — `pap(p, q)` agreeing
  with `sepp(p, q)` would be a bug. What holds is that each vector-argument
  routine agrees with its own angle-argument partner: `pap` with `pas`, `sepp`
  with `seps`.
- **`matrices.rotateX/Y/Z` seed the identity first, and that is load-bearing.**
  `eraRx`, `eraRy` and `eraRz` are in-place rotations of a matrix the caller
  supplies, and each leaves one row exactly as it found it (`src/rx.c:43-55`,
  `ry.c`, `rz.c`), so calling one on an uninitialised matrix yields a matrix with
  an arbitrary row.
- **`atmosphere.refractionConstants` returns a negative `b`**, because upstream
  computes it that way (`src/refco.c:202-203`) and upstream's own oracle value is
  negative (`src/t_erfa_c.c:8006`). Upstream also **silently clamps** its own
  arguments to plausible ranges (`src/refco.c:167-174`) and returns no status;
  this package invents neither a status nor a range error, so an out-of-range
  argument produces an answer computed from the clamped value.

## 5. Files

| Path | What it is |
|---|---|
| `README.md` | this file |
| `README.upstream.md` | upstream's `README.rst` at the pin, byte-for-byte, preserved separately |
| `README.rst` | the same upstream file, still in the tree as upstream material and still digested |
| `README.zig.md` | Zig interface, LLVM requirement, gate record |
| `UPSTREAM.md`, `UPSTREAM.sha256` | provenance, re-pinning procedure, per-file digests |
| `NOTICE.md`, `FORK-LICENSE.md` | per-file licence inventory; the grant for this fork's files |
| `CHANGELOG.md`, `FORK-NOTES.md` | divergence history; problems and fixes |
| `src/` | upstream's tree: 249 core `.c`, 4 public headers, 2 validation programs |
| `zig/`, `tests.zig`, `smoke.zig`, `consumer/` | the Zig surface |
| `runtime/` | the runtime route: `library.zig`, `graph.zig`, plus the driver-supplied core |
| `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml`, `.envrc` | standalone Nix packaging; devenv is canonical, and every task in `devenv.nix` locates this directory itself |
| `LICENSE`, `INFO` | upstream's BSD-3-Clause terms with the SOFA derivation preamble, and the IAU SOFA Board's relicensing permission. **Neither covers this fork's files.** |

## 6. Licence

Upstream's files are BSD-3-Clause with the SOFA derivation preamble (`LICENSE`),
shipped byte-for-byte with `INFO`, the IAU SOFA Board's relicensing permission.
Four upstream files declare themselves **not** derived from SOFA and one test
file declares that and then carries the SOFA-derivation footer anyway; all of it
is itemised by path and line in `NOTICE.md`. **No SOFA endorsement is claimed or
implied**: clause 3 of `LICENSE` bars using the SOFA Board's, the IAU's or its
contributors' names to endorse derived products, and nothing here does.

This fork's own files — build graph, Zig sources, tests, consumer, workflow,
packaging and these documents — are **BSD-3-Clause**, granted by the package
owner directly for those additions, which upstream's grant does not reach.
`FORK-LICENSE.md` carries the authorization, the SPDX identifier and the
boundary; `NOTICE.md` §4 is the per-path inventory.
