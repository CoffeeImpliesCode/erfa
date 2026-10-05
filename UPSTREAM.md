# UPSTREAM.md — provenance of the ERFA material in this package

Status vocabulary follows `foundation-libs/AGENTS.md` §2. Everything below is
`SOURCE-CONFIRMED` unless it says otherwise. **No build, test, smoke run,
cross-target check, formatter, linter, compiler probe, `zig` invocation or git
command was run to produce this file.** Every statement is a read-out of a file
in the tree, with the path and line it came from.

## 1. Identity of the upstream, and how the pin was read

| Fact | Value | Where it was read |
|---|---|---|
| Repository | `https://github.com/liberfa/erfa.git` | `.git/config`, `[remote "upstream"] url` |
| Local branch name | `main` | `.git/HEAD` |
| Pinned commit | `1a8044cde5b7763295d472a6443387239127c6c8` | `.git/refs/heads/main` (file content) |
| Release tag `v2.0.1`, tag object | `944bc0956f1d236e5982ee63930e060e60ec85f9` | `.git/packed-refs` |
| `v2.0.1` peeled commit (the ancestor) | `9915ba38c9365f8b0738269b8c2ac1fdd5f8dee3` | `.git/packed-refs`, `^` line under the tag |
| SOFA base | `20231011` | `meson.build:29`, `configure.ac:23`, `README.rst:55` |
| Package version reported at runtime | `2.0.1` | `meson.build:3`, `configure.ac:5`, `README.rst:55` |
| libtool version info `(current, revision, age)` | `9, 1, 8` | `meson.build:15`, `configure.ac:20` |
| Archive of the pin (whole tree) | `5137fc806f882a6ff70acaa0b91819d3d3a8db34f99366c8472eff6cc99280a8`, 2,498,560 bytes, 269 regular files | driver run, `local://foundation-project-matrix-source-pins.json` |

The remote URL is a **file value**, not a service query. Nothing in this record
asserts that a remote exists or is reachable; no host, no branch, no commit
author and no release date was observed. The checkout's own `refs/heads/main` is
the authority for the pin, which is exactly the commit the package is prepared
from.

**The archive digest in the table is the driver's measurement, not mine.** On
2026-10-03 the driver ran `git archive --format=tar
1a8044cde5b7763295d472a6443387239127c6c8` in this directory (exit 0) and
hashed the complete tar stream and every regular file in it; the receipt is
`local://foundation-project-matrix-source-pins.json`, which states its own
method and records that no archive file was retained. **This is an archive of
the pinned git tree, not a release asset**: it is not the upstream
`erfa-2.0.1.tar.xz`, and no release-asset digest exists for this pin.

That record also carries a per-file digest for each of the 269 files. **Those
269 digests were compared against digests measured independently by hashing this
checkout's files: identical membership, identical digests, zero mismatches, zero
files only in the archive and zero files only here.** Every one of the 269 files
matched the pinned commit. `UPSTREAM.sha256` carries 268 of them; the 269th,
`.gitignore`, was later appended to by the build role and is now recorded as a
deviation in §2 and `NOTICE.md` §4 rather than digested at a digest it no longer
has.

`v2.0.1` is an annotated tag: `packed-refs` carries the tag object and its peel
line separately, so `944bc095…` is not a commit. The ancestor commit named in
the contract is the peeled value, read from the same file.

The relationship between the pin and the tag, and the claim that no SOFA
algorithm source changed between them, comes from an external comparison
reported in `local://foundation-project-matrix-ScreenErfa.md` §1. **This
package does not re-assert it as measured.** What is measurable here, and is
recorded below, is the observable consequence: the leap-second state in
`src/erfadatextra.c:22-23` is `ERFA_THREAD_LOCAL`, and `ERFA_THREAD_LOCAL` is
defined by the macro chain at `src/erfadatextra.h:38-50`, which upstream
describes as added for thread safety (`src/erfadatextra.h:26-37`). No core
`.c` file in this tree contains any thread-local or platform macro other than
that chain; see §6.

## 2. What is retained, and what is compiled

The pinned commit has 269 regular files. **268** of them are listed with measured
SHA-256 digests in `UPSTREAM.sha256` (2,281,788 bytes total). The 269th is
`.gitignore`, which this fork edits on purpose and therefore records as a
deviation rather than digesting: upstream's 24 patterns are kept byte-for-byte
and in order, and the fork appends `!/m4/`, `!/m4/erfa-numver.m4` and six Zig
build-output patterns. Upstream digest
`e84d726d8ebf4331d491995ff5ff0a49a64f0b8740e29d21191d307eb05e793d`; as shipped
`7804ec5be7cbf3051e6bea43fcca210e02edbb110242a0eca574c01132b340ee`. Full
record in `NOTICE.md` §4. **No `.c` and no `.h` file is modified.**

**The README is now carried at two paths, and only one of them is fork's.**
`README.rst` stays exactly where upstream put it, byte-identical, and its digest
is `UPSTREAM.sha256`'s `c70af9a82e6258eb0712acf61498929c69e7d6d2beba4682b11a15fc8a3ceefd`
(line 60). `README.upstream.md` is a **byte-for-byte copy of that file**,
preserved separately so that the fork's own `README.md` does not replace or
mislabel upstream's document. The driver extracted and byte-verified the copy;
the receipt is `local://foundation-contract-upstream-readme-proof.json`, entry
`erfa`, which records `primary_readme: README.rst`, `preserved_path:
README.upstream.md` and the digest above.

It is deliberately **not** a line in `UPSTREAM.sha256`. The manifest's path set
is the pinned commit's own file list, which is what stops a fork-authored file
from entering it by accident, and `README.upstream.md` is not in that list. Its
integrity is recorded instead: the expected digest is stated above, in
`NOTICE.md` §3a and in `FORK-LICENSE.md` §4, so `sha256sum README.upstream.md`
is a check a reader can run without any new tooling. Adding the copy to the
manifest would record the same digest twice for the same bytes and would
weaken the rule that its path set is the pin's.

The manifest's path set is the pinned commit's own file list, not a directory
walk, so a fork-authored file cannot enter it by accident.

**Compiled core — 249 translation units.** The authoritative list is
`liberfa_la_SOURCES` at `src/Makefile.am:2-35` and the `library('erfa', …)`
argument list at `src/meson.build:6-39`. Both were extracted mechanically and
compared entry by entry: 249 names each, 249 unique each, identical sets **and
identical order**. Every one of the 249 exists on disk, and the only `.c` files
on disk outside that list are the two test mains.

**Installed public headers — 4.** `erfa.h`, `erfam.h`, `erfaextra.h`,
`erfadatextra.h`: `include_HEADERS` at `src/Makefile.am:37` and
`install_headers` at `src/meson.build:46` name the same four, and the tree has
exactly these four `src/*.h`.

**Upstream test programs — 2.** `src/t_erfa_c.c` (10,331 lines) and
`src/t_erfa_c_extra.c` (181 lines). `TESTS`/`check_PROGRAMS` at
`src/Makefile.am:49-52` and the `foreach` at `src/meson.build:48-51` name the
same two.

**Retained but never invoked by this package** — `src/Makefile.am`,
`src/meson.build`, `Makefile.am`, `meson.build`, `configure.ac`,
`m4/erfa-numver.m4`, `bootstrap.sh`, `erfa.pc.in`,
`.github/workflows/ci_workflows.yml`, `README.rst`, `RELEASE.rst`, `LICENSE`,
`INFO`, and `.gitignore` (which is also the one of these that this fork edits —
see §2). They are kept as upstream material and *not* used as a build system:
this package compiles the C sources directly and never runs autotools, automake,
meson, CMake, Make or a build-time download. `bootstrap.sh:16` runs `autoreconf`,
which this package does not do.

There is no upstream data directory, no fixture directory, no `test/`,
`include/`, `python/` or `doc/` directory, and no `CMakeLists.txt` anywhere in
the tree. All ephemeris coefficients are `static const double` arrays inside the
`.c` files (`src/epv00.c`, `src/plan94.c`, `src/moon98.c`, and the other series
files); no file is opened, read or downloaded at build or run time.

## 3. Generated `config.h`

Upstream generates exactly one generated input, `config.h`
(`src/meson.build:1-2`, `AC_CONFIG_HEADERS([config.h])` at `configure.ac:7`).
`config.h` is not in the tree — `.gitignore:3` ignores `/config.*`.

Its only consumer is `src/erfaversion.c`, which wraps
`#include <config.h>` in `#ifdef HAVE_CONFIG_H` (`src/erfaversion.c:15-17`) and
then reads five macros: `PACKAGE_VERSION`, `PACKAGE_VERSION_MAJOR`,
`PACKAGE_VERSION_MINOR`, `PACKAGE_VERSION_MICRO` (`src/erfaversion.c:20-37`) and
`SOFA_VERSION` (`src/erfaversion.c:40-42`). `src/meson.build:2` adds
`-DHAVE_CONFIG_H` project-wide; `meson.build:24-29` sets exactly those five
values from `project(version: '2.0.1')` and a hardcoded `'20231011'`.

This package therefore writes `config.h` as a **deterministic build step** from
those five recorded inputs, and puts its directory on both the compile line and
the translation line. `src/erfaversion.c` is the only file that includes it.

**No native source was modified.** There is no patch to any `.c` or `.h` file in
this tree. Every deviation from upstream is build configuration, declared in
`FORK-NOTES.md`.

That holds for the one deviation that could most easily have tempted a patch.
Calling `eraApco13` from Zig with the **default** backend, in `Debug`, returns
the wrong status — `1` where `0` and `-1` are correct — on a Zig 0.16.0 gate
that is recorded, with its receipt, in `FORK-NOTES.md` entry 18 and
`CHANGELOG.md` entry 9. The fix is `.use_llvm = true` in `build.zig` and
`consumer/build.zig`, and nothing else: `src/apco13.c` and `src/erfa.h` are
byte-identical to the pin, are still digested in `UPSTREAM.sha256`, and carry
no `#define`, no shim and no conditional. The rule this package holds itself to
is that a defect on the Zig side of a C boundary is fixed on the Zig side of
the build, never in the upstream bytes.

The NetBSD translation route is the second instance of the same rule, and it
holds for a heavier reason. `zig/translate.h` restates the compiler's own
`__int128_t` and `__uint128_t` under `__SIZEOF_INT128__`, ahead of the four
headers, because NetBSD's `machine/cdefs.h` names `__ALIGNBYTES` in terms of a
typedef that Clang predeclares and no libc header repeats. That declares a
compiler builtin; it does not modify an upstream declaration, and
`src/erfadatextra.h`, `src/erfa.h`, `src/erfam.h` and `src/erfaextra.h` remain
byte-identical to the pin and remain digested in `UPSTREAM.sha256`. The route
and the bridge are recorded in full, with their two gate receipts, in
`FORK-NOTES.md` entry 19 and `CHANGELOG.md` entry 10.

## 4. Link dependency

`libm`, and nothing else. `meson.build:32` —
`cc.find_library('m', required: false)`; `configure.ac:26` —
`AC_SEARCH_LIBS([sin],[m], , AC_MSG_ERROR(...))`. `src/erfa.h:15` includes
`math.h`.

## 5. Relicensing authority

`INFO` is retained byte-for-byte and carries the relicensing authority. It
records that the IAU Standards of Fundamental Astronomy Board, in a letter from
Catherine, Chair, IAU SOFA Board, HM Nautical Almanac Office, UK Hydrographic
Office, approves relicensing a changed SOFA library by the NumFOCUS Foundation
under a "Three Clause BSD" license, on two conditions: all function names change
the `iau` prefix to `era`, and the SOFA Board is removed as a copyright holder
(`INFO:4-9`). `INFO` is a provenance record, not a licence.

`LICENSE` is retained byte-for-byte: BSD-3-Clause terms with the SOFA
derivation preamble (`LICENSE:4-15`), the acknowledgement request
(`LICENSE:22-23`), and clause 3's no-endorsement term (`LICENSE:38-41`). The
clause-3 term is a prohibition on using the SOFA Board, the IAU or its
contributors' names to endorse or promote derived products without prior
written permission. **This package makes no such use and asserts no SOFA
endorsement.** `LICENSE` is carried unmodified and is the licence for the
upstream files; per-file terms are itemised in `NOTICE.md`.

## 6. Portability-relevant structure of the native sources

Measured across all 255 files in `src/` (251 `.c` + 4 `.h`):

- **Include graph.** `erfa.h` ×250, `erfam.h` ×108, `stdlib.h` ×4
  (`src/af2a.c`, `src/moon98.c`, `src/tf2a.c`, `src/tf2d.c`), `string.h` ×3
  (`src/d2dtf.c`, `src/dtf2d.c`, `src/t_erfa_c_extra.c`), `erfaextra.h` ×3,
  `erfadatextra.h` ×2, `stdio.h` ×2, `float.h` ×1 (`src/jd2cal.c`), `math.h` ×1
  (`src/erfa.h`), `config.h` ×1 (`src/erfaversion.c`). The five `src/` files
  that do not include `erfa.h` are `erfa.h`, `erfam.h`, `erfaextra.h`,
  `erfadatextra.h` and `erfaversion.c`.
- **`erfa.h` does not include `erfam.h`.** 107 of the 249 core `.c` files
  include `"erfam.h"` themselves; 142 rely on `erfa.h` alone. Upstream states
  this is deliberate (`README.rst:66-68`). Any translated header pair must
  reproduce both, and `src/t_erfa_c.c:1-2` mixes `<erfa.h>` with `"erfam.h"`.
- **No platform conditionals beyond one chain.** The whole `src/` tree contains
  exactly seven distinct `#if`-family directives: the four include guards,
  `__cplusplus` for `extern "C"`, `#ifdef HAVE_CONFIG_H`, and the single
  `ERFA_THREAD_LOCAL` selection chain at `src/erfadatextra.h:38-50`
  (C++11/C23 `thread_local` → C11 `_Thread_local` → `_MSC_VER`
  `__declspec(thread)` → `__GNUC__`/`__clang__` `__thread` → empty). The macro
  is referenced in exactly two files, `src/erfadatextra.h` and
  `src/erfadatextra.c`.
- **No allocation.** A whole-tree scan for `malloc`, `calloc`, `realloc`,
  `free`, `alloca` and `strdup` found none. `sprintf` appears three times, all
  in `src/t_erfa_c_extra.c:31,38,45` (a test program); no core `.c` file uses
  it. Every result is written into caller-provided storage.
- **Word size.** No 64-bit-only assumption was found in the sources: `long` is
  used in `src/cal2jd.c` for intermediates far below 2^31, and the largest
  documented accepted Julian Date, `DJMAX = 1e9`, fits in a 32-bit signed
  integer. This is a source-reading observation, not a portability result.

**One of these is now a gate result, the other is not.** The libc-less
`aarch64-macos-none` question is answered as far as a compile can answer it:
the six-target `check` compiles that target through the library, the tests, the
facade exercise, the smoke example and both upstream validation programs, so
`math.h`, `string.h`, `stdlib.h`, `float.h` and `stdio.h` all resolve for it
(`local://foundation-matrix-erfa-six-baseline.log`, `Build Summary: 55/55 steps
succeeded`). Nothing has *run* there, so no runtime claim exists. The
`wasm32-wasi` `__thread` question is unchanged and still not established here:
that target builds and is never executed, which shows the chosen spelling was
accepted and not which branch was taken. Neither is a platform limitation and
neither is recorded as a failure.

## 7. Leap-second data and how to maintain it

The leap-second table and the drift table are compiled-in constants in
`src/dat.c`, not data files and not a download:

- `static const eraLEAPSECOND _changes[]` at `src/dat.c:150` — **42 entries**,
  measured; first `{ 1960, 1, 1.4178180 }` at line 151, last
  `{ 2017, 1, 37.0 }` at line 192, years 1960–2017. The derived count
  `enum { _NDAT = (int) (sizeof _changes / sizeof _changes[0]) }` is at
  `src/dat.c:196`.
- `static const double drift[][2]` at `src/dat.c:129` — **14 rows**, measured,
  first `{ 37300.0, 0.0012960 }`, last `{ 39126.0, 0.0025920 }`, consumed via
  `enum { NERA1 = … }` (`src/dat.c:147`) and applied at `src/dat.c:242`.
- `enum { IYV = 2023 }` at `src/dat.c:126` — the release year of this version of
  `eraDat`.

**The dated cliff.** `src/dat.c` contains the single line
`if (iy > IYV + 5) j = 1;`. With `IYV = 2023`, `j = 1` is the "dubious year"
**warning** for every call whose year is 2029 or later; the value is still
computed. Today (2026-10-03) that threshold is three years out. This is a
`SOURCE-CONFIRMED` reading of the source and a dated consequence, not an
observed failure.

**Upstream's own maintenance procedure**, stated verbatim in the doc block at
`src/dat.c:14-42` and not altered here: when a new leap second is announced,
(1) add a line to the initialiser set for `changes` (`src/dat.c:21-23`);
(2) set `IYV` to the current year (`src/dat.c:25-26`); (3) update the "Latest
leap second" comment, currently `2016 December 31` (`src/dat.c:28-30,40`);
(4) set the "This revision" comment to the current date, currently
`2023 January 17` (`src/dat.c:32-33,119`). Step (2) must also be carried out
whenever the function is re-issued even if no leap second was added
(`src/dat.c:35-38`).

**How this package maintains that data.** A leap-second update is an upstream
source change. This package does not hand-edit `src/dat.c`: the table, `IYV`,
the comments and the revision date are upstream-owned bytes, covered by
`UPSTREAM.sha256`, and they change only by re-pinning to an upstream commit that
contains them and re-measuring the manifest. Until then the fork's contribution
is the ability to re-pin without waiting for a distribution. The last table
entry in this pin is 2017-01-01 at ΔAT = 37.0 s.

**What a caller may do instead of waiting for a re-pin.** Upstream ships the
replacement hook `eraSetLeapSeconds` (`src/erfaextra.h`, `src/erfadatextra.c`),
and it is the only supported way for a user to carry a newer table without
patching `src/dat.c`. Two properties of it are worth recording here because
they are **upstream's**, not this fork's, and because both are invisible from
the declaration:

- It retains the **caller's** pointer with no copy and no check — its own note
  reads "*No* sanity checks are performed" (`src/erfadatextra.c:60-65`). The
  caller's storage must therefore stay alive and unmodified until the next
  replacement or reset **on that thread**, since at this pin the active-table
  pointer and its length are `ERFA_THREAD_LOCAL` (`src/erfadatextra.c:22-23`;
  at the `v2.0.1` tag both were process-global plain `static`).
- A replacement table is consumed **positionally**. `eraDat` finds the
  preceding entry with a scan over `12*iyear + month` (`src/dat.c:231-233`),
  applies the pre-1972 drift correction by the **index** it found,
  `if (i < NERA1) da += (djm + fd - drift[i][0]) * drift[i][1]`
  (`src/dat.c:241-242`) with `NERA1` derived from the 14-row `drift` table
  (`src/dat.c:129-147`), and compares the pre-UTC boundary against
  `changes[0].iyear` (`src/dat.c:222`). So a valid replacement is the
  **complete built-in table with new rows appended in ascending date order**;
  a short modern table re-points the drift model and moves the pre-UTC
  boundary, and does so silently even when it is correctly sorted.

This package documents that contract on the facade and exercises it in
`tests.zig`; it does not change any of it, and `src/dat.c` remains upstream's
byte-for-byte.

## 8. Re-pinning procedure

1. Read the target commit out of the upstream checkout's ref file; record it in
   §1 of this file.
2. Re-measure every digest in `UPSTREAM.sha256` and update the file in place.
3. Re-derive the `config.h` inputs in §3 if `project()` version or `SOFA_VERSION`
   moved.
4. Re-state `NOTICE.md`'s per-file inventory only if the *set* of files or any
   file's in-file notice changed; the counts there are measured, not assumed.
5. Record the change in `CHANGELOG.md` as `PENDING-VERIFICATION` and let the
   driver move it.
6. Re-measure §7's counts — `_changes` entries, `drift` rows, the derived
   `NERA1`, and the `IYV` value and therefore the dubious-year threshold — and
   update every document that quotes them. `NERA1` is a positional bound, so a
   re-pin that changes the `drift` table changes which replacement leap tables
   are valid; that has to be re-read, not carried forward from this pin.
7. Re-check §6's portability facts, in particular whether the
   `ERFA_THREAD_LOCAL` chain still selects the same branch
   (`src/erfadatextra.h:38-50`); the per-thread claims in §1 and §7 and in
   `FORK-NOTES.md` entry 4 all depend on it.
8. Re-extract `README.upstream.md` from the new pin's primary README and
   re-verify it byte-for-byte, exactly as the 2026-10-04 extraction was
   verified (§2). Update the digest stated in §2, `NOTICE.md` §3a and
   `FORK-LICENSE.md` §4 together — three places, one value — and add the
   re-verification receipt. A stale digest there is a provenance defect, not a
   documentation preference.

## 9. What this record does not claim

- This file is a provenance record and nothing else. The gates that *were* run
  for this package are recorded where they belong — `CHANGELOG.md` entries 8,
  9 and 10, `FORK-NOTES.md` entries 18 and 19, and `README.zig.md` §9a — each
  with its receipt. What is true of those receipts is true here too: the native
  results are per-mode single runs on the native target (`Debug`, `ReleaseSafe`,
  `ReleaseFast`, `ReleaseSmall`), the 53-platform matrix is the **corrected** run
  `20261003-194646-57707-28197` in which every target builds and 20 of them run
  the suite, and the installed-C result was taken against the install that
  `zig build install` produces from the tree as it stands, by the driver and
  outside CI; that program is the installed-C job's own C source, taken from
  `.github/workflows/verify.yml` and compiled and run unchanged. **The package
  round trip — filtered tarball, cached fetch, consumer built from the fetched
  copy — is driven and recorded outside this repository**, in
  `local://foundation-matrix-final-package-proof.json`; that record, and only
  that record, is what can establish an outcome for it, and this file asserts
  none in either direction. The driver did not execute
  `.github/workflows/verify.yml`, and this file asserts no CI result in either
  direction. No gate result may be added anywhere in this package without a
  driver-observed run.
- **`sha256sum -c UPSTREAM.sha256` has been run in this directory**: exit 0, 268
  files, every line `OK`
  (`local://foundation-matrix-erfa-provenance-checksums.log`). The manifest is
  therefore verified in the checkout as well as reconciled against the pinned
  archive in §1. The pristine comparison has also been re-run: 269 native
  upstream files checked against the pin, `.gitignore` the only reported
  difference — the deviation `CHANGELOG.md` entry 7 records
  (`local://foundation-matrix-source-integrity.json`, `native_upstream.erfa`).
  The manifest's own exclusion of that one file is therefore what keeps both
  results clean, and neither result says anything about the `.gitignore`
  contents beyond the 24 upstream patterns being present verbatim.
- No release asset was downloaded, so no `erfa-2.0.1.tar.xz` digest exists for
  this pin. The one archive digest recorded in §1 is the driver's
  `git archive` of the pinned commit, and every digest in `UPSTREAM.sha256` was
  computed from a file in this checkout; the two sets agree exactly.
- No vcpkg, conda, distro or system-library presence was observed either way.
- This package ships **no system mode** for this wave; there is therefore no
  system-integration gate, and none is claimed. `erfa.pc.in` is retained as
  upstream material and is not used.
- The claim "no SOFA algorithm source changed between `v2.0.1` and the pin" is
  reported by the external comparison in the ScreenErfa report and is not
  re-derived here.