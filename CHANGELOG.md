# CHANGELOG — fork-only divergences

Upstream's release history lives in `RELEASE.rst` in the upstream tree and is
not restated here. This file records **only** what this fork changed or added
relative to ERFA at `1a8044cde5b7763295d472a6443387239127c6c8` (upstream branch
`main`; ancestor `v2.0.1` = `9915ba38c9365f8b0738269b8c2ac1fdd5f8dee3`; SOFA
base `20231011`; package version `2.0.1`), written so a re-sync can replay it.
Numbers are stable identifiers; never renumber them.

Statuses are the workspace's (`foundation-libs/AGENTS.md` §2). Entries 1–7 are
`SOURCE-CONFIRMED`: every statement is a read-out of a file, and the gate that
would confirm each one is named here wherever it has since been run. Entries 8
and 10 are `VERIFIED` at the scope their receipts carry, entry 9 is `OBSERVED`
and `VERIFIED` for its published contract, and each names the driver receipt
that bounds it. `README.zig.md` §9a is the single index of receipts and §9b the
single statement of boundaries. The package round trip is recorded outside this
repository, in `local://foundation-matrix-final-package-proof.json`; nothing in
this file claims anything about the packaged bytes, in either direction.

Entries 11–14 were written on 2026-10-04 for the contract migration and are
**`PENDING-VERIFICATION` in full**: no build, test, cross-target check, `nix`
or `devenv` invocation has looked at any of them, and every receipt quoted
above was taken against the tree as it stood on 2026-10-03, before them.

Entry 16 is `SOURCE-CONFIRMED` for its shape and arithmetic and
**`PENDING-VERIFICATION`** for everything a gate would confirm, on the same
rule: it was found by a red receipt taken on 2026-10-04
(`local://foundation-resumed-erfa-loaded-static-ReleaseSafe.json`, quoted in
entry 16 and carried as a row in `README.zig.md` §9a.2), and **no gate has
looked at the tree since the correction landed**. The red receipt is the
finding; it is not evidence that the correction works.

## 1. Added the provenance record for a checkout-imported upstream

`UPSTREAM.md`, `UPSTREAM.sha256`, `NOTICE.md`, `README.zig.md`, `FORK-NOTES.md`,
`CHANGELOG.md` and `.github/workflows/verify.yml` are new.

**Why the manifest is a superset of what is compiled.** The compiled closure is
249 `.c` plus 4 headers, but the checkout also retains upstream's autotools,
meson, Make, pkg-config and GitHub-Actions files. They are kept as material and
digested rather than dropped, because deleting retained upstream material is
not this fork's call and because a manifest that silently omits shipped files is
not an integrity record.

The manifest holds **268 records**: the pinned commit's own 269 regular files
minus `.gitignore`, which is a recorded deviation (entry 7). The path set comes
from the pinned commit's file list rather than from a directory walk, so a
fork-authored file cannot enter it by accident.

**The pin's archive digest is now measured.** The driver ran
`git archive --format=tar 1a8044cde5b7763295d472a6443387239127c6c8` in this
directory on 2026-10-03 (exit 0) and hashed the complete tar stream —
`5137fc806f882a6ff70acaa0b91819d3d3a8db34f99366c8472eff6cc99280a8`, 2,498,560
bytes, 269 regular files — receipt
`local://foundation-project-matrix-source-pins.json`. That record carries a
per-file digest for each of the 269 files, and those were compared against the
269 digests measured independently from this checkout's files: **identical
membership, identical digests, zero mismatches.** That is an archive of the
pinned git tree; it is not the upstream `erfa-2.0.1.tar.xz`, and no
release-asset digest exists for this pin.

**Status.** `VERIFIED` in both directions. The digests are `SOURCE-CONFIRMED`
and reconciled against the pinned archive as described above, and the
`sha256sum -c` gate itself has now been run in this directory:
`sha256sum -c UPSTREAM.sha256`, exit 0, 268 files, every line `OK`
(`local://foundation-matrix-erfa-provenance-checksums.log`).

## 2. Measured the authoritative core list instead of trusting one build file

**Decision.** Treat `src/Makefile.am:2-35` *and* `src/meson.build:6-39` as the
specification and require them to agree.

**What was measured.** Both lists were extracted mechanically: 249 names each,
249 unique each, identical sets and identical order. Every listed file exists;
the only `.c` files on disk outside the list are `src/t_erfa_c.c` and
`src/t_erfa_c_extra.c`.

**Why it matters.** Building from either file alone would be a single point of
failure; this package builds neither, and the agreement is what licenses the
claim that "every core `.c` except the test mains" is exactly 249 files rather
than approximately that many.

**Status.** `SOURCE-CONFIRMED`.

## 3. Replaced the generated `config.h` with a deterministic write-files step

**Decision.** `config.h` is written at build time from five recorded values —
`PACKAGE_VERSION "2.0.1"`, `PACKAGE_VERSION_MAJOR 2`, `_MINOR 0`, `_MICRO 1`,
`SOFA_VERSION "20231011"` — from `meson.build:3,24-29`, `configure.ac:5,23` and
`m4/erfa-numver.m4`. `HAVE_CONFIG_H` is defined and the generated directory is
on both the compile line and the translation line.

**Why the translation line too.** `src/erfaversion.c:16` includes
`<config.h>` by bare name, so the directory has to be reachable at translation
time or the single consumer of the generated header fails to parse. An
installed header is not on the compile line; include paths belong on both.

**Status.** `VERIFIED`. Every mode in `README.zig.md` §9a compiles this tree,
and the `preprocess erfa translate.h` step under the NetBSD translation is the
one that would have failed if the generated directory were missing from the
translation line — it succeeds in all 11 steps
(`local://foundation-matrix-erfa-netbsd-preprocess-check-r2.log`). The
`erfa.h` write and the `config.h` write are both present under every target in
the six-target `check` (`local://foundation-matrix-erfa-six-baseline.log`).

## 4. Kept every upstream byte, including the ones that are inconvenient

No `.c` and no `.h` file in this tree is patched. In particular the three
things a packager is tempted to "fix" are shipped exactly as upstream wrote
them, each recorded in `NOTICE.md`:

- the leap-second warning cliff `if (iy > IYV + 5) j = 1;` (`src/dat.c`),
- the leap-second table's last entry, 2017-01-01,
- `src/t_erfa_c_extra.c`, which declares itself not derived from SOFA at line 6
  and ends with a SOFA-derivation BSD-3 footer at lines 120-181.

**Status.** `VERIFIED`. The driver compared this tree's 269 native upstream
files against a pristine import of the pin and the **only** difference reported
is `.gitignore` — the deviation entry 7 records on purpose.
`local://foundation-matrix-source-integrity.json`, `native_upstream.erfa`:
`files_checked: 269`, `differences: [".gitignore"]`. No `.c` and no `.h` file
differs, which is exactly the claim this entry makes.

## 5. Carried no licence grant onto fork-authored files

`build.zig`, `build.zig.zon`, `zig/translate.h`, `zig/root.zig`,
`zig/api_exercise.zig`, `tests.zig`, `smoke.zig`, `consumer/**`,
`cross-test.profile.sh`, `.github/workflows/verify.yml` and the six
provenance files listed in entry 1 assert **no licence**. ERFA's BSD-3 grant
names NumFOCUS Foundation as copyright holder and does not reach them. The
owner's decision for these files is open and is recorded as open in
`NOTICE.md` §4 rather than answered by borrowing.

**Status.** `SOURCE-CONFIRMED`.

**Superseded by entry 12.** As of 2026-10-04 these files are no longer without
a licence: the owner authorized a `BSD-3-Clause` grant for them directly. This
entry records the state before that authorization and is kept as history; it is
not renumbered and it is not deleted.

## 6. Shipped no system mode, and recorded that as a fact

This wave defines no system-integration option, so there is no system gate to
pass and none is claimed. `erfa.pc.in` and `erfa.pc` are retained as upstream
material and are not used. Any later wave that adds a system mode must translate
the real selected installed headers, not a bundled copy, and must not reuse the
source pins or the bounded contracts of this wave unchanged.

**Status.** `CONSTRAINT` by design, and now `VERIFIED` as an assertion about the
build: every gate in `README.zig.md` §9a ran without a system mode, no
`pkg-config` or installed-library lookup appears in any of them, and
`erfa.pc.in` stayed unused. No system gate exists and none is claimed.

**Superseded in part by entry 13.** `erfa.pc.in` is still never **executed**:
the Zig build graph still does not run it, and there is still no system mode and
no system gate. What changed is that `package.nix` now **substitutes** the
template to write `$out/lib/pkgconfig/erfa.pc` for a source-built output. That
is packaging metadata for this derivation's own output, not a
system-integration option, and it does not make this entry's constraint false.

## 7. Appended to `.gitignore`, and recorded it instead of re-recording a digest

**The one carried upstream file this fork edits.** All 24 of upstream's
patterns are preserved byte-for-byte and in their original order. Appended:
`!/m4/` and `!/m4/erfa-numver.m4`, because upstream's `/m4/` would otherwise
swallow a file this package ships, lists in `.paths` and digests; then
`/.zig-cache/`, `/zig-out/`, `/zig-pkg/` and the three `consumer/`-anchored
equivalents. Upstream digest
`e84d726d8ebf4331d491995ff5ff0a49a64f0b8740e29d21191d307eb05e793d`; as shipped
`7804ec5be7cbf3051e6bea43fcca210e02edbb110242a0eca574c01132b340ee`.

**Why it is absent from `UPSTREAM.sha256` rather than present at the new
digest.** A file at its upstream digest would fail `sha256sum -c` on a known,
intended deviation; a file re-recorded at its edited digest would make that
deviation invisible. Both are worse than saying so. The deviation is stated in
three places — the manifest header, `NOTICE.md` §4 and `FORK-NOTES.md` entry 13
— and `verify.yml` checks it as a deviation: absent from the manifest, noted in
the manifest, named in `NOTICE.md`, and all 24 upstream patterns still present as
exact lines in original order.

**Status.** `VERIFIED`, on the same comparison: 269 native upstream files
checked, `.gitignore` the single reported difference, no `.c` and no `.h` file
patched (`local://foundation-matrix-source-integrity.json`).

## 8. Corrected the typed route against the pinned sources

No native byte changes. Everything below is in fork-authored Zig only, and every
line cited is `src/` at the pin.

**`calendar.cal2jd` publishes the wrong thing for two of its three failures.**
`eraCal2jd` returns `-1`/`-2` before writing either output and `-3` after
writing both (`src/cal2jd.c:68-84`). One inequality inverted both: `-3` came
back as "absent" and `-1` was built from two uninitialised doubles. The two
negative statuses are now named explicitly.

**The equation of the origins is now named as such.** `Apco13Result` and
`Atco13Result` publish `equation_of_origins` (was
`equation_of_equinoxes`), `precession.eo06a` says origins, and
`precession.eors`'s second parameter is `cio_locator_s` in radians rather than
an arcsecond scale (`src/eors.c:14-27`, `src/apco13.c:220-221`). The value did
not change; the name did, and the old name described a different angle.

**`rotation.apio13` no longer returns unwritten members.** `Astrom` is now the
sixteen members `eraApco` writes (`src/apcs.c:142-170`,
`src/apco.c:182-220`; `eraASTROM.phi`, declared at `src/erfa.h:31`, is assigned
by nothing in `src/`), and the new `ObservedAstrom` is the nine `eraApio`
writes (`src/apio.c:140-166`). The raw record stays on `erfa.c` as
`c.eraASTROM`.

**Three documented inputs now say what upstream means.** The `lt*` family takes
an absolute TT Julian epoch, not years from J2000.0 (`src/ltpecl.c:13`,
`src/ltpequ.c:84`); `calendar.epb`/`epj` return the year plus fraction counted
from 2000.0 (`src/epj.c:53`); `vectors.ld`'s fifth argument is
`observer_distance` in au, not a companion mass (`src/ld.c:14-20,87-89`).

**`Gd2gceResult` documents its unreachable `-1`.** The guard is a sum of
non-negative terms (`src/gd2gce.c:73-74`), so no finite argument reaches it.

**Two contracts that were simply missing are now written down**, in
`zig/root.zig`'s doc comments and in `README.zig.md` §3b and §6:

- *The leap setter's lifetime and index boundary.* `leap.setLeapSeconds`
  retains the caller's slice with no copy and no check
  (`src/erfadatextra.c:60-65`), so the caller owns the storage until the next
  replacement or reset **on that thread**, must keep it alive and unmodified,
  and may mutate it only between calls. Its doc also states the part the
  signature cannot: `eraDat` applies the pre-1972 drift correction by **table
  index**, `if (i < NERA1) da += …` (`src/dat.c:241-242`, `NERA1 == 14` from
  the 14-row `drift` table), and compares the pre-UTC boundary against
  `changes[0].iyear` (`src/dat.c:222`). So a valid replacement is the complete
  built-in table with modern rows appended in ascending date order, and a
  two-row modern table is invalid **even when it is sorted**.
- *Units, and which quantity is which.* `Astrom.em` is the Sun→observer
  distance in **au**, not a mass — `eraApcs` computes it as
  `eraPn(ph, &astrom->em, astrom->eh)` (`src/apcs.c:157-158`) — as is
  `vectors.ld`'s `observer_distance` (`src/ld.c:14-20,87-89`). Angles are
  radians, geodetic height is metres, `pmt` is Julian years, `delta_at` is SI
  seconds, positions are au and velocities au/day, and every `epoch` argument
  is an absolute Julian epoch. `README.zig.md` §3b now carries the table
  rather than leaving each caller to re-derive it.

**Partial output is stated per result, not per library.** `README.zig.md` §3b
now tabulates, for every result type that can reject a call, what a rejection
leaves behind — and the three residues are kept distinct, because upstream
uses all three: `eraCal2jd`'s `-1`/`-2` write nothing (`date` is `null`) while
its `-3` still computes the date (`src/cal2jd.c:68-69,75-84`); `eraGc2gd`
writes `-1e9` into all three outputs (`src/gc2gd.c:74-79`); `eraGd2gc` writes
zeroes (`src/gd2gc.c:48-49`); `eraGc2gde` writes nothing at all and leaves the
caller's own values in place (`src/gc2gde.c:76-77,84`). Collapsing those three
behaviours into one "absent on error" would have been a fourth, invented one.

**Tests and the exercise were corrected, not weakened.** Each change below
replaces an expectation the pinned source contradicts with the behaviour the
source has, and every expected value is still an independent one:

- `jd2cal` split-independence now compares JD 2450124.4999 in three splits; the
  previous alternative splits denoted a different instant.
- `utcut1` uses the UTC part `src/t_erfa_c.c:9759` states instead of the part
  `ut1utc` returned, a difference larger than the tolerance.
- The leap-table replacement test no longer asserts a status for a date before
  the replacement's first entry at all. It asserted `−5`, which
  `src/dat.c:222` pre-empts with the warning `+1`, and chasing a reachable `-5`
  is what pushes an author towards installing a short modern table. It now
  builds the only valid replacement — the whole built-in table copied into
  caller storage, with `{2020,1,38.0}` and `{2022,7,39.0}` appended — checks the
  three resulting ΔAT values, then writes `40.0` into that same caller storage
  between two `dat` calls and reads `40.0` back, which proves the pointer was
  retained rather than asserted (`tests.zig:513-543`). The reason the prefix is
  mandatory is `src/dat.c:241-242`: the pre-1972 drift correction is applied
  by **table index** (`i < NERA1`, `NERA1 == 14`), not by year, and
  `src/dat.c:222` compares against `changes[0]`.
- `eqeq94` uses MJD 41234.0, the input `src/t_erfa_c.c:3607` uses.
- `gd2gce` with flattening 2.0 asserts the computed result; the `-1` it
  asserted cannot occur.
- `epb2jd(1957.3)` is MJD 35948 and `epj2jd(1996.8)` MJD 50375, both read off
  the exercise's own published inputs.
- Every timescale round trip compares the two parts. Collapsing a two-part date
  into one sum measures the ulp of 2.45e6 (4.7e-10), not the conversion.
- Constant, copy and duplicate-content checks were removed from
  `zig/api_exercise.zig`; `tests.zig` keeps the reference values.

**`consumer/src/main.zig` compiles and asserts.** Seven `reportStatus` results
were discarded, so a wrong status exited zero; each is now propagated. The raw
route call `erfa.c.eraAtan2` named a routine no shipped header declares; it is
replaced with `eraAnpm`, which `src/erfa.h:447` does declare.

**Status.** `VERIFIED` for what the receipts below cover, and the receipts are
the sequence, not a single run:

- `local://foundation-matrix-erfa-before-complete-runtime.log` — Debug, native,
  exit 1, `38/51 tests passed (13 failed)`. This is the state these
  corrections landed against. Historical; superseded.
- `local://foundation-matrix-erfa-semantic-r4.log` — `zig build test smoke
  consumer upstream-test`, Debug, native, exit 1. `51/51 tests passed`, smoke
  green, consumer green, and `upstream-test success` with **both** `t_erfa_c
  validation successful` and `t_erfa_c_extra validation successful`; the facade
  exercise alone red on one transcribed value: `expected
  0.8921045614537038, got 0.8921006945555556`.
- `local://foundation-matrix-erfa-semantic-r5.log` — `zig build test smoke
  consumer -j2 -Doptimize=Debug --summary all`, Debug, native, exit 0:
  `Build Summary: 15/15 steps succeeded; 51/51 tests passed`, with
  `run exe erfa-exercise success`, `smoke success` and `consumer success`.
- `local://foundation-matrix-erfa-current-debug-r1.log` — `zig build install
  test smoke consumer upstream-test -j2 -Doptimize=Debug --summary all
  --prefix …/erfa/install`, Debug, native, exit 0: `Build Summary: 24/24 steps
  succeeded; 51/51 tests passed`, with `install success`, `test success`
  (`run test 51 pass (51 total)` and `run exe erfa-exercise success`),
  `smoke success`, `consumer success` and `upstream-test success`, both
  upstream programs printing `validation successful`.

**What that does and does not make this entry.** Against the tree as it stands,
the test suite, the facade exercise, the smoke example and the consumer program
all pass on the native target in **every** supported mode: `Debug`,
`ReleaseSafe`, `ReleaseFast` and `ReleaseSmall`, 51/51 in each
(`local://foundation-matrix-erfa-releasesafe-native.log` — `20/20 steps`, with
`upstream-test` — `…-releasefast-native.log` and `…-releasesmall-native.log`,
`15/15 steps` each). Wider, but still bounded: the six-target `check` compiles
all six required `-Dtarget` triples (`55/55 steps`), the 53-platform matrix
executed all 51 tests on **20** targets and built all 53
(`local://foundation-matrix-erfa-cross-corrected-summary.json`, run id
`20261003-194646-57707-28197`: `pass 20, fail 0, build_only 33, exit_code 0`),
and a C program against the current install compiles, links and runs
(`local://foundation-matrix-erfa-installed-c-current-compile.log` /
`-run.log`) — that program is the installed-C job's own C source, taken from
`.github/workflows/verify.yml` and compiled and run unchanged by the driver
outside CI. **Outside this entry's scope:** the package round trip is driven
and recorded in `local://foundation-matrix-final-package-proof.json`, and the
driver did not execute `verify.yml`, so no CI result is claimed either way.
`README.zig.md` §9b and §9c state both boundaries and are where each is
settled.

## 9. Made LLVM a published consumer requirement, because the default backend returns the wrong `eraApco13` status

**What changed.** Build configuration only, in two files:

- `build.zig` — `.use_llvm = true` on the `addTest` root and on every
  `addExecutable` root it owns: the facade exercise, the smoke example and the
  consumer program. Named rather than line-numbered, because that file belongs
  to the build role and its line numbers move.
- `consumer/build.zig` — `.use_llvm = true` on its own executable root.

**No `.c` and no `.h` file is touched.** `src/apco13.c` and `src/erfa.h` are
byte-identical to the pin and stay in `UPSTREAM.sha256`. There is deliberately
no shim: no `#define`, no reordering wrapper, no `#if` around the call, and no
"detect and report differently" path.

**Why, as an observed fact.** On 2026-10-03 the driver compiled one probe
program twice against **one** archive, changing nothing but the backend flag —
Zig 0.16.0, `-ODebug`, native target, both exit 0:

| Probe call | Default backend | `-fllvm` |
|---|---|---|
| `eraApco13` raw, valid 2013 date `2456384.5 + 0.969254051` | `1` (wrong) | `0` (correct) |
| `eraApco13` typed, same date | `1` (wrong) | `0` (correct) |
| `eraApco13` raw, unacceptable date `−1e10 + 0` | `1` (wrong) | `−1` (correct) |
| `eraApco13` typed, same date | `1` (wrong) | `−1` (correct) |
| `eraUtctai`, both dates | `0` / `−1` | `0` / `−1` (unchanged) |

Receipts `local://foundation-matrix-erfa-boundary-isolation.log` and
`local://foundation-matrix-erfa-boundary-llvm-discriminator.log`; the argv
lines differ only by a leading `-fllvm`, and both link the same
`…/o/3fc96734ab923532bbeb6b9530bfc70e/liberfa.a`, the same `zig/root.zig` and
the same `translate.zig`.

**What the numbers mean.** `+1` is upstream's *dubious year* warning
(`src/dat.c:69-78,225`): it still computes, and 2013 is nowhere near the 2029
threshold. So under the default backend a caller that treats non-zero as
failure rejects a good date, and a caller that accepts a positive status as
success accepts `−1e10` as valid. A wrong status here is a wrong answer, not a
crash.

**Cause: not established, and not claimed.** The archive, the facade logic and
the raw/typed call shapes differ not at all between the two runs, and
`eraUtctai` — three arguments, same probe, same runs — is correct in both. The
defect is in the Zig front end's handling of that call. This package did not
bisect it and asserts no mechanism.

**The half of the fix that does not travel with the package.** A module cannot
force a dependent's backend: the choice belongs to the `addExecutable` /
`addTest` root, which the dependent owns. So `.use_llvm` in `build.zig` fixes
this package and its own consumer, and **every external consumer must set it
itself**. That is why the requirement is published in `README.zig.md` §1a, in
§4's cost table, and as a consumer `build.zig` that demonstrates it, rather
than being left as an implicit property of one repository's build file.

**The requirement is on Zig roots, and only Zig roots.** Every Zig executable or
test root that imports this package's `erfa` module — this package's own test
root, exercise, smoke and consumer, and any external consumer's root — must
set `.use_llvm = true`. A pure C program linking `liberfa.a` has no Zig root
and needs no flag; the installed-C program in `README.zig.md` §9a is compiled by
`zig cc` with no backend flag at all, links, and runs. The flag buys a correct
status on a call that crosses the C ABI from Zig, and only such a call can need
it.

**Status.** `VERIFIED` for the contract as published. The two discriminator runs
are `OBSERVED` and are what establishes the defect; what the later gates add is
that the flag holds in every mode this package supports — `Debug`,
`ReleaseSafe`, `ReleaseFast` and `ReleaseSmall` each run all 51 tests green,
and the 53-platform matrix runs all 51 on 20 further targets
(`README.zig.md` §9a). The six-target `check` compiles all six required
triples. The installed-C consumer is **not** evidence for this entry: it is a C
program and exercises no Zig call, so it neither confirms nor refutes the
defect, exactly as before. What remains unestablished is the **cause**, and it
is unestablished in every mode: no run without `-fllvm` exists outside
`-ODebug`, so nothing here says the default backend is wrong everywhere, only
that this package does not rely on it anywhere. The flag is set in every mode
because a mode-dependent workaround nobody has measured is a worse contract
than one unconditional flag.

## 10. Translated `zig/translate.h` through the target's own C preprocessor on NetBSD, and nowhere else

**What changed.** `build.zig` and `zig/translate.h`, both fork-authored, both
build-only. **No `.c` and no `.h` upstream file is touched**, the four public
headers and all 35 macros still reach the translation, and the generated
`config.h` still reaches it on the same include path it reaches the
compilation. The `.use_llvm` roots of entry 9 are unchanged.

**What the build now does.** `zig translate-c` parses C with **Aro**, which
preprocesses as well as parses. `aggregateRoute` picks per target between two
ways of reading `zig/translate.h`, and the two differ in exactly one respect —
which preprocessor has to understand the target's C library:

- `.aro` on every target but NetBSD: the translator preprocesses
  `zig/translate.h` for itself and parses the result. **Unchanged from before.**
- `.preprocessed` on NetBSD: `preprocessedAggregate` first runs
  `zig cc -E -dD` — the compiler running this build script, so the same pinned
  one, given `-target <triple>` when the target is not native — with the same
  include path, the same generated `config.h` directory and a `-MD`/`-MF`
  dependency file, and `addTranslateC` then parses what that wrote.

The condition is the **OS tag**, `target.result.os.tag == .netbsd`, not a list
of nine triples, because the whole family shares one header and one cause; a
triple list would silently stop covering the next architecture.

**Why NetBSD alone.** `erfa.h:15` reaches exactly one system header, `math.h`,
and no other. Every other C library in this matrix spells `__END_DECLS` as
plain tokens. NetBSD's does not: `generic-netbsd/sys/cdefs.h:431-432` routes
`__END_DECLS` through `__BEGIN/END_PUBLIC_DECLS`, which `:411-416` defines as
`extern "C"` framing around `_Pragma("GCC visibility push(default)")` and
`_Pragma("GCC visibility pop")`. `<math.h>` closes every declaration block with
`__END_DECLS`, so every NetBSD translation drags two `_Pragma` operator
invocations in; Aro destringizes each into a `#pragma` line and hands it to the
parser as C. The observed **pre-route** full-matrix run reported **five errors
at `math.h:607`** for that reason on all nine NetBSD targets and on no other
target, **with the C archive itself compiled**.

**Why `-dD` and not a plain `-E`.** Without it the expansion carries no macro
definitions and `pub const c` loses them. `erfam.h` is almost entirely macros,
so `ERFA_DJM0`, `ERFA_DAYSEC` and `ERFA_WGS72` would drop out of the
translation and a C caller reading them as macros would stop getting constants.
`-dD` keeps the `#define` lines beside the expanded text, so a macro stays a
macro across the route. Nothing is stubbed, narrowed, renamed or substituted
on this route; the aggregate header is read with every `#include` resolved,
every conditional settled, every definition kept.

**The second thing NetBSD's headers needed, and what it is not.** The route
above is necessary but was not sufficient, and the re-gate is what proved it:
with the route in place, `zig build check -Dtarget=aarch64-netbsd` still failed
with `Build Summary: 7/11 steps succeeded (3 failed)` and three red steps, all
of them the Zig roots, all with `use of undeclared identifier '__int128_t'`
(`local://foundation-matrix-erfa-netbsd-preprocess-check-r1.log:3-6`) — the C
archive, both upstream validation programs and the `preprocess` step were
already green. Cause: `generic-netbsd/arm/cdefs.h:62-63` spells `__ALIGNBYTES`
as `sizeof(__int128_t) - 1` under `__ARM_PCS_AAPCS64`, a predefine the compiler
supplies for AArch64, and **no header declares the typedef** — Clang declares
`__int128_t`/`__uint128_t` next to `__int128` itself, not in a libc header, so
`-dD` preserved the spelling into a file that named an undeclared identifier.

Fix: three lines at the top of `zig/translate.h`, ahead of the four includes —
under the compiler's own capability macro `__SIZEOF_INT128__`,
`typedef __int128 __int128_t;` and `typedef unsigned __int128 __uint128_t;`.
**This is not a patch to native code and not a macro redefinition.** It
restates the compiler's own builtin 128-bit integer typedef in the one file
`zig translate-c` reads, which is the declaration the expansion was referring
to. **No `.c` and no `.h` upstream file is touched**, nothing else of the C
library is restated, `__ALIGNBYTES` and every other macro NetBSD's headers
contribute stay as those headers spell them, `x86_64-netbsd` needs none of it
(`x86_64-netbsd-none/machine/cdefs.h:6` spells `sizeof(long) - 1`), the 32-bit
NetBSD targets leave the guard false, and a target with no `__int128` declares
neither. The same convention `pcre2` and `lmdb` carry in this workspace.

**Status.** `VERIFIED` for the translation, at compile scope. `zig build check
-Dtarget=aarch64-netbsd -j2 --summary all` now reports `Build Summary: 11/11
steps succeeded`, with `preprocess erfa translate.h` sitting under the
translation
(`local://foundation-matrix-erfa-netbsd-preprocess-check-r2.log`), and the
corrected 53-platform matrix builds **all nine** NetBSD targets —
`aarch64-netbsd`, `aarch64_be-netbsd`, `arm-netbsd`, `armeb-netbsd`,
`mips-netbsd`, `mipsel-netbsd`, `powerpc-netbsd`, `x86-netbsd`,
`x86_64-netbsd`, each `build: pass` with `run: unavailable`
(`local://foundation-matrix-erfa-cross-corrected-summary.json`, run id
`20261003-194646-57707-28197`: `pass 20, fail 0, build_only 33, exit_code 0`).
**Compiled is not executed**: no NetBSD target has ever been run, and none is
claimed to have been. The non-NetBSD route is unchanged and is exercised by
the six-target `check` (`local://foundation-matrix-erfa-six-baseline.log`,
`Build Summary: 55/55 steps succeeded`, all six required `-Dtarget` triples),
which compiles and likewise runs nothing.

## 11. Gave the package a fork README, and kept upstream's README under its own name

**What changed.** `README.md` is new and is the fork README, in this order:
current native-source deviations, current native-build deviations with a dated
history link, the build/run/test matrix, consumption. `README.upstream.md` was
extracted and byte-verified by the driver as a preserved copy of upstream's
`README.rst`; receipt
`local://foundation-contract-upstream-readme-proof.json`, entry `erfa`:
`primary_readme: README.rst`, `preserved_path: README.upstream.md`,
`sha256 c70af9a82e6258eb0712acf61498929c69e7d6d2beba4682b11a15fc8a3ceefd` —
the same digest `UPSTREAM.sha256:60` records for `README.rst`.

**`README.rst` was not moved and not renamed.** It stays in the tree exactly
where upstream put it, byte-identical and digested, because deleting retained
upstream material is not this fork's call. `README.upstream.md` is a **copy**,
and `UPSTREAM.md` §2, `NOTICE.md` §3a and `FORK-LICENSE.md` §4 each state that
relationship and the one digest all three must agree on.

**Why the copy is not in `UPSTREAM.sha256`.** The manifest's path set is the
pinned commit's own file list — that is exactly what stops a fork-authored file
from entering it by accident — and `README.upstream.md` is not in that list. Its
expected digest is recorded in prose in three places instead, so
`sha256sum README.upstream.md` is a check a reader can run without new tooling.
Adding the copy would record the same digest twice for the same bytes and would
weaken the rule the path set exists to enforce.

**Status.** `PENDING-VERIFICATION`. The relocation itself is a fact about the
tree; no gate has re-run `sha256sum -c UPSTREAM.sha256` since.

## 12. Granted a licence to this fork's own files, by the owner's authorization

**What changed.** `FORK-LICENSE.md` is new, and `NOTICE.md` §4 no longer says
"no licence asserted". Every file this fork authored is now **`BSD-3-Clause`**
(SPDX `BSD-3-Clause`), granted by the owner of this package directly for those
additions. The authorization itself is recorded in `foundation-libs/AGENTS.md`
§8, which is quoted in `FORK-LICENSE.md` §1.

**Why that term.** It is ERFA's own primary term, from `LICENSE`, so a
downstream that already accepts upstream's terms accepts these files on the same
ones. The grant is plain BSD-3-Clause: it carries **none** of the SOFA
derivation preamble, the "unaltered state" note or the acknowledgement request
that `LICENSE` carries, and it asserts **no** SOFA derivation and **no** SOFA
endorsement.

**What it does not do.** It does not re-grant, extend or reinterpret anything
upstream granted, and it does not re-issue the two conditions `INFO` records for
the ERFA relicensing. Those bind upstream's files. Upstream's `LICENSE` and
`INFO` are retained byte-for-byte and both are installed by the Nix output.

**The copyright line.** The holder is the owner who granted it. No individual
name is asserted anywhere, because this record knows none and inventing a
personal copyright identity would be a fabrication. `FORK-LICENSE.md` §2 gives
the literal line to use where a tool demands one.

**The boundary that matters here.** `README.upstream.md` is **not** one of the
fork's files. It is upstream material under upstream's terms, and it is
deliberately absent from the §4 list. Earlier revisions that recorded "no
licence asserted" described the state before the authorization; they are
superseded by it, not by any change to upstream's terms.

**Status.** `PENDING-VERIFICATION`. No licence scanner or gate was run; this is
a record, not an audit result.

## 13. Added standalone source-only Nix packaging, with devenv as the canonical environment

**What changed.** Five new files: `package.nix`, `flake.nix`, `devenv.nix`,
`devenv.yaml`, `.envrc`. None of them edits a build file, and none of them is
imported by one.

**`package.nix` is the single derivation**, consumed by `flake.nix` and
`devenv.nix` through `pkgs.callPackage`. There is no `../workspace` import, no
host account name, no store path and no build-time download anywhere in it. It
takes `zig` as an argument **with no default**, so both call sites name
`pkgs.zig_0_16` out loud, and it asserts `zig.version == "0.16.0"` at evaluation
time rather than quietly building with whatever was passed.

**Two variants, one SDK.** `linkage` is `"static"` (the default, and what this
graph hard-coded before any option existed) or `"dynamic"`. Same 249 sources,
same four headers, same generated `config.h`; only the artefact kind differs.
**Static means a static library artefact.** No wholly-static-executable claim is
made. The variants are named at the entry points — `packages.<system>.static`
and `.shared`, `outputs.static` and `outputs.shared` — and `default` is the
SDK's own policy.

**The shared variant's precondition has since been met.** As this entry was first
written, `-Dlinkage` did not exist in `build.zig`; it landed the same day. See
entry 14.

**Install contents — corrected by entry 14.** This entry originally had the
derivation installing `erfa.pc`, the licence records and the doc records
itself. That was wrong and it was removed: an install layout described in two
places is two answers to one question, and `build.zig`'s `addPkgConfig` renders
a *relocatable* `erfa.pc` that a second, absolute-prefix `substitute` would
have overwritten. The layout is now entirely `zig build install`'s to write and
`package.nix` writes nothing into `$out` but the one build invocation.

**The dev shell is tools-only.** The SDK is deliberately **not** in
devenv.nix`'s `packages`: entering the shell must not require building the
library to get a prompt. `outputs` are lazy and call the same `package.nix`, so
`devenv build outputs.static` and `outputs.shared` are the packaging route. The
pinned `nixpkgs` inputs are named by revision in `flake.nix` and `devenv.yaml`,
and **neither lock file is written here** — the driver owns them and records the
narHash from an observed lock run.

**What it does not restate.** No C flag, no include path and no linkage macro is
duplicated from `build.zig`; those are declared once, in the build graph. The
derivation exports both Zig cache variables under the Nix-provided `TMPDIR`,
outside the source tree, and honours a caller-supplied value rather than
unsetting one. `devenv.nix` names no host path at all.

**Status.** `PENDING-VERIFICATION`. Nothing here has been evaluated, built,
realised or entered through `nix` or `devenv`.

**Closed by entry 14.** `build.zig.zon`'s `.paths` and `verify.yml`'s
fork-record check were the two places that had to learn about these files, and
both were updated.

## 14. The build graph took over the whole install layout, and gained `-Dlinkage` and `-Druntime`

Landed by the native-delivery role on 2026-10-04, recorded here because it moves
facts this file and `README.md` state. **No gate has observed any of it.**

**`-Dlinkage=static|dynamic` now exists**, as
`b.option(std.builtin.LinkMode, "linkage", …)` defaulting to `.static`. Three
properties are worth recording because they are the ones a reader would
otherwise have to derive:

- **The default is a no-op, not a change.** The static path passes
  `pic = null`, and `Module.pic` is a `?bool`: `appendZigProcessFlags` emits
  `-fPIC`, `-fno-PIC` or nothing for `true`, `false` and `null`. Passing
  `false` would have put a flag on a command line that has never carried one and
  made "the default" a change.
- **The shared artefact carries upstream's own ABI version**, `(9, 1, 8)` from
  `configure.ac:20` via `ERFA_LIB_VERSION_INFO`, with a soname and version
  links. It is not a linkage flip on the same file.
- **A target with no dynamic linker refuses the request.**
  `std.Target.DynamicLinker.kind` answers from the OS tag alone — WASI is
  `.none` — so `-Dlinkage=dynamic` for `wasm32-wasi` is **refused loudly**
  rather than answered with a static archive, because a caller who asked for a
  shared object did not ask for a different artefact. An earlier draft of this
  entry described a substitution and a printed notice; the build refuses, and
  `verify.yml` and `cross-test.profile.sh` both gate it.

**The install layout is now the build graph's alone.** `addPkgConfig` reads
upstream's `erfa.pc.in` and substitutes it in Zig — field names, order and
upstream's own `Name:`/`Description:`/`Libs:` spellings preserved — with
`@prefix@` rendered as `${pcfiledir}/../..` so the installed file is
**relocatable**. `installRecords` writes `share/licenses/erfa/`
(`LICENSE`, `INFO`, `NOTICE.md`, `FORK-LICENSE.md`, `UPSTREAM.md`) and
`share/doc/erfa/` (`README.upstream.md`, `README.rst`), and `LICENSE` + `INFO`
still land at the prefix root. `package.nix` was corrected to stop writing any
of those paths; see the correction inside entry 13.

**`-Druntime` is wired.** It selects the *dispatch* and is orthogonal to
`-Dlinkage`: under it the library is still built and installed, because a caller
may name a provider this tree did not build and may equally want the one it
did. `addGraph` imports `c` from `runtime_graph.createModule(b, translate,
target, optimize)` instead of `translate.createModule()`, skips
`module.linkLibrary(c_lib)` entirely, and the **linked** branch instead imports
`rt` from `createCoreModule(b, target, optimize)`. That last detail is a
correctness requirement, not a convenience: `LoadSource` and `LoadError` are
this SDK's public types and have to be the *same* types in one build, so the two
branches must not both call `createCoreModule` — a second core instance would
be a second, nominally distinct `LoadSource` that `erfa.load` could not accept.
Default off; a linked build is unchanged in every respect.

**`runtime/library.zig` and `runtime/graph.zig` landed.** `library.zig` already
carries `SPDX-License-Identifier: BSD-3-Clause`, the identifier entry 12 grants;
`graph.zig` carries no SPDX header yet and should. They are ERFA's half of the
route — what a provider must be, and how it is wired — and this build calls
them and defines none of the route itself. Its synchronization prefix is
`erfa_rt`, so `runtime/sync.c`'s symbols cannot collide with another SDK's.

**What is still absent is the reusable core**: `runtime/loader.zig`
(`graph.zig:205`), `runtime/sync.c` (`graph.zig:265`), `runtime/generate.zig`
(`graph.zig:291`) and the `runtime/sync.h` that C includes. They are
driver-owned and are copied into each SDK from the BLAKE3 pilot, so the route is
**source-complete but not yet buildable**: `-Druntime=true` cannot compile until
they land. The facade half of the route is done: `zig/root.zig` exports
`runtime_loaded` (`root.zig:201`), `LoadSource` (`root.zig:209`), `LoadError`
(`root.zig:215`), `load(source)` (`root.zig:241`) and `loadedSource()`
(`root.zig:257`) for whichever configuration has them. No gate has run any of
that, so this package still claims no external ABI family and no
loaded-consumer behaviour. What it does record is the boundary a loader will
have to cross: the leap-second state has internal linkage and is in no symbol
table at all, so there is no data symbol to read by address and the accessors
are the whole interface.

**Status.** `PENDING-VERIFICATION`. The gates this entry needs are in
`README.md` §3.3.

**Closed since this entry was first written.** `build.zig.zon`'s `.paths` now
carries `runtime` as a whole directory plus `package.nix`, `flake.nix`,
`devenv.nix`, `devenv.yaml`, `README.md`, `README.upstream.md` and
`FORK-LICENSE.md` beside the records already listed; `.envrc` is deliberately
excluded, with the reason in the manifest's own comment. `verify.yml`'s
provenance job now gains a second step asserting every installed file is inside
`.paths`, and its record-presence list includes `FORK-LICENSE.md`, `README.md`,
`README.upstream.md`, the packaging files and `runtime/graph.zig` +
`runtime/library.zig`. That last one is what makes this entry installable
outside this tree: `zig build install` reads `NOTICE.md`, `FORK-LICENSE.md`,
`UPSTREAM.md`, `README.upstream.md` and `README.rst` out of the source, so a
`.paths` that omitted them would have made a fetched or packaged copy unable to
install its own licence records.

**A declaration count that disagreed with itself, found and corrected.** Three
fork-authored comments said the four headers declare 249 or 257 entry points.
A mechanical count over the headers gives `erfa.h` **247**, `erfaextra.h` **7**
(`eraVersion`, `eraVersionMajor`, `eraVersionMinor`, `eraVersionMicro`,
`eraSofaVersion`, `eraGetLeapSeconds`, `eraSetLeapSeconds`), `erfadatextra.h`
**1** (`eraDatini`), and `erfam.h` 35 macros with no function — **255** in total,
which is what `README.zig.md` §2a already recorded. **249** is the number of
core translation units in `src/Makefile.am`; the two were conflated. The API role
re-counted independently, got 255, and corrected `zig/root.zig:129-132`,
`runtime/library.zig:17-20` and `runtime/graph.zig:279-281` on 2026-10-04.

**It never reached code.** `runtime/graph.zig:281-301` generates the dispatch by
running the generator over what `translate-c` actually emitted for the selected
target, and `provider_excluded` is a name list, empty. No count is hardcoded in a
code path, so the defect was one misleading comment rather than a latent
load-time failure, and no behavioural gate is owed for it. `README.md` §4.5 now
states 255 as the measured figure and names 249 as the distinct
translation-unit count.

**Open, pending the driver's own run rather than excluded:** the four
driver-owned runtime-core files, and with them every `-Druntime` gate in
`README.md` §3.3.

## 15. The typed route reached the whole vector, matrix, angle, catalogue and atmosphere surface, and four of its identities are not bitwise

Landed during the contract wave of 2026-10-04, recorded here because it moves
counts this file and `README.md` state and because it is where the four
arithmetic traps in `README.zig.md` §3d came from.

**The typed surface grew from 99 members in 8 namespaces to 197 in 18.**
Measured from `zig/root.zig` as it now stands: `leap` 3, `calendar` 13,
`timescale` 18, `rotation` 20, `geodetic` 5, `precession` 36, `ephemeris` 3,
`vectors` 31, `matrices` 20, `angles` 4, `spherical` 6, `horizon` 3,
`ecliptic` 3, `galactic` 2, `gnomonic` 6, `atmosphere` 1, `starCatalogs` 9,
`fundamentalArgs` 14. The 197 wrap **197 distinct C functions**, all of which
are real declarations in the four headers — checked mechanically, none invented
— and the other 58 of the 255 stay reachable through `c`. Against `erfa.h`
itself the coverage is 194 of 247, and the 53 untyped declarations are confined
to `Astronomy/Astrometry` (21) and `Astronomy/PrecNutPolar` (32), which are the
intermediate `eraAp*`/`eraAtci*`/`eraC2i*`/`eraC2t*` stages that upstream
composes into the entry points the facade does expose. Outside `erfa.h`, three
of the eight are typed (`eraGetLeapSeconds`, `eraSetLeapSeconds`,
`eraDatini`) and the five that are not are the version accessors.

**The result records grew with it.** There are now **34** records whose name
ends in `Result`, of which **29** carry a `status`; the five that do not are
`D2tfResult`, `A2afResult`, `A2tfResult`, `Fk5HipResult` — whose C routines
return `void` — and, outside that suffix, `Geodetic`, which is an input to
`gd2gc`/`gd2gce` rather than a result at all. The record this file's entry 8
described as 28 counted `Geodetic` among them.

**Four non-status `int` returns are now typed, and the two that were always
typed are named for what their integer is.** `leap.getLeapSeconds` and
`leap.datini` return entry counts; `gnomonic.fromStandardCoordinates` and
`gnomonic.fromVector` return `0`, `1` or `2` as the **count of useful
solutions** (`src/tpors.c:23-26`, `src/tporv.c:23-26`) — entry 19 corrects the
"plus a conditioning report" wording this entry first carried, and the
`src/tpors.c:26-33` citation below with it. `TporsResult` documents that a
count of `0` is the case where **nothing** was written, so `isOk()` is true
while both solutions are `null` (`src/tpors.c:115-117`) — a caller must read the
optional members, not the status, to know whether there is an answer. Only
`eraVersionMajor`, `eraVersionMinor` and
`eraVersionMicro` remain on the raw route.

**Four identities that a caller will get wrong, and what the package does about
them.** Each is argued from source in `README.zig.md` §3d.

1. **`eraPvxpv(a, a)` is zero in real arithmetic and need not be zero in
   floating point.** `eraPxp` forms each component as `ya*zb - za*yb`
   (`src/pxp.c:43-45`), so a self-cross is a difference of two equal products —
   exactly `0.0` under IEEE-754 — unless the compiler contracts the multiply-add
   into an `fma`, which leaves the rounding error of one product instead. The
   self-cross **velocity** member, `a_p × a_v + a_v × a_p` (`src/pvxpv.c:46-50`),
   has the same property. The check is a `1e-14` absolute tolerance. Exact
   equality is kept only where upstream's expression cannot round: `eraPmp` and
   `eraPpp` are componentwise `-` and `+` (`src/pmp.c`, `src/ppp.c`).
2. **`eraPvu` copies the velocity and rounds the product; `eraPvup` may fuse it.**
   `eraPvu` is `eraPpsp(pv[0], dt, pv[1])` followed by `eraCp(pv[1])`
   (`src/pvu.c:37-38`) — the velocity is **not** scaled by `dt`, and `eraPpsp`
   computes `s*b` into a temporary before adding (`src/ppsp.c`). `eraPvup` writes
   `pv[0][i] + dt * pv[1][i]` in one expression (`src/pvup.c:37-39`). The two
   can therefore differ in the last bit; neither is more correct, and no
   bitwise identity is claimed between them.
3. **Position angle is not separation.** `eraPap` returns the bearing of `b`
   from `a` in `[-pi, pi]`, north zero and east positive
   (`src/pap.c:20-24,84`), and `eraPas` is the same quantity from longitude and
   latitude; `eraSepp` returns the angle *between* two directions in `[0, pi]`
   via `atan2(|a×b|, a·b)` (`src/sepp.c:44-46`) and `eraSeps` is its
   longitude/latitude form. The package checks `pap` against `pas` and `sepp`
   against `seps` — each routine against its own partner — and never one against
   the other.
4. **`eraRx`, `eraRy` and `eraRz` are in-place rotations of a matrix the caller
   supplies, and each leaves one row exactly as it found it** — `eraRx` mixes
   rows 1 and 2 (`src/rx.c:43-55`), `eraRy` rows 0 and 2, `eraRz` rows 0 and 1.
   The identity seed is therefore load-bearing, not decoration, and `eraIr`
   writes all nine entries (`src/ir.c:20-28`) so the seed is complete.

**The refraction constants are signed, and no validation is invented.**
`eraRefco` computes `*refa = gamma * (1 - beta)` and
`*refb = -gamma * (beta - gamma / 2)` (`src/refco.c:202-203`) with
`beta = 4.4474e-6 * tk` (`src/refco.c:198`), so for any ordinary observing
temperature `refb` is **negative**; upstream's own pinned oracle value is
`-0.2598658261729343970e-6` (`src/t_erfa_c.c:8006`). The sign is the model's, and
the wrapper neither flips it nor takes an absolute value. `eraRefco` returns
`void`, so there is no status to carry, and it **clamps its own arguments**
silently with `ERFA_GMAX`/`ERFA_GMIN` — temperature to `[-150, 200]`, pressure
to `[0, 10000]`, humidity to `[0, 1]` and wavelength to `[0.1, 1e6]`
(`src/refco.c:167-174`, `erfam.h:106-109`). An out-of-range argument therefore
produces an answer computed from the clamped value and no diagnostic. This
package adds neither a status nor a range error, and `README.md` §4.6 says so
where a consumer will meet it.

**Status.** `SOURCE-CONFIRMED` for every claim above: each is read out of the
pinned sources or out of `zig/root.zig` as it stands, and no native byte is
touched. The behavioural gates are in `README.md` §3.2b and
`README.zig.md` §9a.2, and the four arithmetic claims are exercised by the
facade exercise rather than asserted from this file: the self-cross tolerance,
the `pvu` position at `1e-14`, the `pap`/`pas` and `sepp`/`seps` pairings, the
identity-seeded rotations and the refraction signs are all checked there
(`zig/api_exercise.zig:679-688`, `:753-778`).

## 16. `vectors.s2xpv` returned three doubles where upstream writes six

Landed during the contract wave of 2026-10-04, recorded here because it is the
one **breaking** change to the typed route this wave and because the receipt
that found it is red.

**The defect.** `zig/root.zig` declared
`pub fn s2xpv(s1: f64, s2: f64, pv: Pv) Vec3` and handed `eraS2xpv` a `Vec3`
to write into. Upstream's fourth parameter is `double spv[2][3]`
(`src/erfa.h:517`), and `eraS2xpv` fills it with two independent `eraSxp`
calls — `eraSxp(s1, pv[0], spv[0])` and `eraSxp(s2, pv[1], spv[1])`
(`src/s2xpv.c:31-32`), each a single multiply per component
(`src/sxp.c:27-29`). **Six doubles were written into a three-double object**,
three of them past its end. The old doc comment called the result
`s1 * p + s2 * v`, a three-component vector sum; there is no addition anywhere
in `src/s2xpv.c`, and upstream states the result as "pv-vector: p scaled by
s1, v scaled by s2" (`src/s2xpv.c:17`) and tests all six components
(`src/t_erfa_c.c:8615-8647`).

**The fix.** The signature is `pub fn s2xpv(s1: f64, s2: f64, pv: Pv) Pv`. The
result is a `Pv`, and both the argument and the result go through the existing
`pvPointer` convention that `vectors.sxpv` already used
(`zig/root.zig:2619-2623`) — no new helper and no second convention. `Pv` is
`extern` and is checked at comptime to have exactly the `double[2][3]` layout
this call needs (`zig/root.zig:701-718`, `pvPointer` at `:739-741`), so the
callee writes six contiguous doubles with nothing copied and nothing moved.
**There is no shim, no alias and no deprecated overload**: a caller that
indexed the old three-component result reads `.position` or `.velocity`
instead.

**What observed it.** The runtime-loaded `ReleaseSafe` run — `zig build smoke
test -Druntime=true -Dlinkage=static -Doptimize=ReleaseSafe`, with
`ERFA_TEST_PROVIDER` naming a shared object this tree installed — exits **1**
with `Build Summary: 10/12 steps succeeded (1 failed); 60/60 tests passed` and
`smoke success`, then dies in the facade exercise: `process terminated with
signal ABRT`, an `Illegal instruction` `@trap()` in the compiler runtime inside
the `s2xpv` dispatch stub, reached from the old `api_exercise.zig:738`
(`local://foundation-resumed-erfa-loaded-static-ReleaseSafe.json`). The test
suite was green throughout, because `tests.zig` had **no test for
`vectors.s2xpv` at all**; the routine's only check was the exercise's
finiteness loop, which reads three of the six numbers and cannot see the three
written past the end. The linked `Debug` row in `README.zig.md` §9a.2 reports
`60/60` with the exercise green, which is why the defect survived it.

**What replaced that check.** `zig/api_exercise.zig:738-751` reads the result
as two members and checks **all six** values against the operands with exact
equality, using scales that differ and one that is negative (`s1 = 3.0`,
`s2 = -0.5`); exact because `eraSxp` is one multiply per component.
`tests.zig:1259-1289` adds one case — *"vectors.s2xpv: two scalars, two members,
six results"* — that likewise checks all six with `==`, on operands chosen so
the products cannot round: `3.0` times a power of two, and `-0.5` times
anything. `tests.zig` is therefore **61** tests, not 60. Both checks begin with
the file's own `nativeReady()` convention, so a runtime-loading run that has
not loaded a provider stops instead of falling through.

**Nothing else moved.** `erfa.vectors` is still **31** members, the typed route
still **197** members over **197** distinct C functions in **18** namespaces,
and `eraS2xpv` is still one of them. No native byte changed: `src/s2xpv.c`,
`src/erfa.h` and `src/t_erfa_c.c` are untouched. Every line number this entry
quotes for `zig/root.zig`, `zig/api_exercise.zig` and `tests.zig` was re-read
after the change, and the five `zig/api_exercise.zig` citations that sat after
line 738 — in this file and in `README.zig.md` §3d — were shifted to match.

**Status.** `SOURCE-CONFIRMED` for the shape and the arithmetic; the receipt
above is the finding, not a clearance. **No gate has run since this change**:
no build, no test, no `check`, no cross-target run, and no `nix` or `devenv`
invocation has looked at the tree as it now stands, so `ReleaseSafe` is red on
the evidence in hand and no mode is certified. `README.zig.md` §3e is the
consumer-facing statement and §9a.2 carries the red row.

## 17. Every `devenv` task now locates this SDK's own directory, and the two installing tasks write outside it

**What changed.** `devenv.nix` only. One `let` binding, `sdkRoot =
builtins.toString ./.;`, and a `cd ${lib.escapeShellArg sdkRoot}` as the first
line of all nine `exec` bodies; `enterShell` gained one banner line. No build
file, no Zig surface, no count and no digest record was touched, and **no task
was renamed**: `sdk:licence` is still the name of the integrity entry, because
that is the name this SDK has always given it, and no `sdk:integrity` alias was
added beside it.

**Why the root is read from this file and not from `$DEVENV_ROOT`.** `./.` is
resolved relative to the file that writes it, so it is this checkout whatever
directory the caller ran from, and `DEVENV_ROOT` is the devenv *project*
directory — a scratch project the caller chose, holding no `build.zig`, no
`UPSTREAM.sha256` and no `consumer/`. `builtins.toString` is used rather than an
interpolated `${./.}` because the interpolated form can pull the whole tree into
the read-only Nix store, and a store copy is not a directory `zig build` may
write a cache into. Every use goes through `lib.escapeShellArg`, so a path with a
space in it is still one argument. This is `FORK-NOTES.md` 28.

**What it fixes.** Two gates of the driver's run of 2026-10-04
(`nix-acceptance-20261004T175328Z`), both failures of correct code:
`devenv tasks run --mode single sdk:consumer` printed `info: initialize build.zig
template file with 'zig init'` and then `error: no build.zig file found, in the
current directory or any parent directories`, and `sdk:licence` printed
`sha256sum: UPSTREAM.sha256: No such file or directory`. devenv materialises a
task as a generated program that starts in the caller's directory.
`sha256sum -c` resolves every path in `UPSTREAM.sha256` against the working
directory, so naming the record by an absolute path would not have been a fix
and the change of directory is the repair.

**The two installing tasks.** `build.zig`'s default step installs — the artefact
at `:1473`, `erfa.pc` at `:1320`, the licence and doc records at `:1336` and
`:1343` — and `zig build`'s own default prefix is `zig-out/` **inside the
checkout**, which is this working tree on a networked filesystem. So `sdk:build`
now passes `--prefix` resolved from **exported** values only: `$ERFA_INSTALL_PREFIX`
if it is set, else `$ZIG_LOCAL_CACHE_DIR/erfa/build` if that is set, else
`$TMPDIR/erfa/build` if that is set; and `sdk:shared-install` keeps its
`-Dlinkage=dynamic`, gains `-j8`, and resolves its own prefix the same way —
`$ERFA_INSTALL`, else `$ZIG_LOCAL_CACHE_DIR/erfa/shared`, else
`$TMPDIR/erfa/shared`. **With none of the three exported there is no default**:
the task prints what to export on stderr and exits non-zero, because a location
this file does not get to invent — `/tmp` is not one of them, and no host path
appears in any of these files. Neither chain has a branch inside the repository,
neither task sets or unsets a variable — an exported value is the caller's and is
used as it is — and the five tasks that do not depend on the install step
(`test`, `smoke`, `consumer`, `upstream-test`, `check`) are given no prefix at
all. `README.md` §3.1 states the same contract for a reader.

**Status.** `PENDING-VERIFICATION`. **No `devenv`, `nix`, `zig` or `git` command
was run against the tree after this change.** The receipts quoted above are the
two failures that motivated it, not a clearance: `sdk:licence` and
`sdk:consumer` have not been re-run since, and only the driver's gate can move
this entry.

## 18. Every `zig build` a `devenv` task runs now names `-j8`, `--summary all` and an external `--cache-dir`

**What changed.** `devenv.nix` only. Three `let` bindings and one rewritten
explanation block, seven rewritten `zig build` lines, one banner line. The
bindings are `cacheDir` (`"$ZIG_LOCAL_CACHE_DIR/erfa/cache"`), `cacheFill` — the
shell block that completes an unset `ZIG_LOCAL_CACHE_DIR` /
`ZIG_GLOBAL_CACHE_DIR` — and `preamble`, which is `cd` to this checkout followed
by that fill. All seven `zig build` routes now read
`zig build [step] --cache-dir "${cacheDir}" [--prefix …] [-D…] -j8 --summary all`:
`sdk:build` (`:136`), `sdk:test` (`:143`), `sdk:smoke` (`:150`), `sdk:consumer`
(`:157`), `sdk:upstream-test` (`:164`), `sdk:check` (`:171`) and
`sdk:shared-install` (`:199`); the first six bodies open with the shared
`preamble` where each had a bare `cd`. `enterShell` runs the same `cacheFill`
first, so an interactive `zig build` and a task agree about where output goes.
No task was renamed, no `description` was reworded, no prefix chain, linkage
default, `-D` or argument forwarding was touched, and `sdk:licence`
(`sha256sum -c`, `:210`) and `sdk:fmt` (`zig fmt`, `:217`) run no compiler and
keep only their `cd`. No build file, Zig surface, count or digest record was
touched.

**The flags, and why they are written in.** `AGENTS.md`:157-158 asks for `-j8`,
`--cache-dir "$CACHE/<repo>/<target>"` and `--summary all` on each library and
consumer build, and the driver's own `route_argv` builds a task route as
`devenv tasks run --mode single <name>` (`verify_nix_acceptance.py`:1302-1304)
and appends nothing to it, so no job count, cache or summary can arrive from
outside once this file has been evaluated. Eight jobs is the rule's own number
and `--summary all` is the format the recorded logs carry, and both sit last so
the step name, `--prefix` and `-Dlinkage` keep the order the receipts quoted in
entries 8 and 10 record.

**Where the cache goes, and when it is decided.** A `zig build` told nothing
writes `.zig-cache` **inside the checkout**, which is this working tree on a
networked filesystem, so every route names `--cache-dir` explicitly. The
directory is `$ZIG_LOCAL_CACHE_DIR/erfa/cache`, beside the two delivery prefixes
entry 17 already resolves under the same root. A caller's exported
`ZIG_LOCAL_CACHE_DIR` and `ZIG_GLOBAL_CACHE_DIR` are its own and are never
overwritten; an unset one is completed from `$XDG_CACHE_HOME` and then from
`$TMPDIR`, and with neither naming a location the body prints on stderr and
exits non-zero rather than falling back to `.zig-cache`, `/tmp` or `/var/tmp`.
**The fill is in the body, not only in `enterShell`**: `devenv tasks run --mode
single` starts a generated program that never sources the shell hook, so a fill
that lived in `enterShell` alone would leave that program building into this
checkout. That also closes the gap entry 17 left — its two prefix chains could
read a `$TMPDIR` root for which nothing had completed a cache.

**Status.** `PENDING-VERIFICATION`, on entry 17's rule. **No `devenv`, `nix`,
`zig` or `git` command was run against the tree after this change, and no
receipt is claimed for it.** What is confirmed here is the file: every
`zig build` reachable from a task in it names all three flags, settles its cache
before the compiler starts, and the two installing tasks still resolve
`--prefix` from exported values only. Only the driver's gate can move this
entry.

## 19. Two published contracts and one thread-safety claim were wrong, the consumer run steps lost `--provider`, and the installing CI cells wrote into the checkout

Landed 2026-10-04 in the numerical-review pass. Fork-authored files only: no
`.c` and no `.h` is touched, no public signature, option, default or install
layout changes, and no new gate is added.

**1. `TporsResult.status` was documented as a quality ladder.** `zig/root.zig`
read "`2` the reference point lies comfortably inside the projection; `+1` it is
within 1 radian of the plane's edge and the result is ill-conditioned" and
called the outputs "the `+1` solution" and "the `-1` solution". Upstream's
integer is a **count of useful solutions** — `0` none, `1` only `Soln. 1` (the
usual case), `2` both, decided by `(fabs(rsb) < 1.0) ? 1 : 2`
(`src/tpors.c:23-26,53-56,114`, `src/tporv.c:23-26,48-51,111`) — and the
outputs are `Soln. 1`/`Soln. 2`, unsigned (`src/tpors.c:19-20`,
`src/tporv.c:19-20`). Both records now quote that ladder and name the outputs as
upstream does, and each says that a count of `1` means the second is not
*useful* rather than absent. `isWarning()` answers true for `1` and `2`
alike, so both records now say that the predicates do not read this integer as
a status. The `gnomonic` namespace header and `README.zig.md` §3a are amended
to the same wording, and the `src/tpors.c:26-33` citation for "nothing was
written" is corrected to `:115-117` (`src/tporv.c:112-114`), which is where
upstream actually returns without writing.

**2. The module documentation's `load` example named a soname this package does
not produce.** `zig/root.zig` and `README.zig.md` §1b both showed
`/usr/lib/liberfa.so.2`. `configure.ac:20` records
`ERFA_LIB_VERSION_INFO(9, 1, 8)`, libtool's `(C - A).A.R` gives `9 - 8 = 1`, and
`build.zig`'s `abi_version` and `meson.build` derive the same `1.8.1`, so the
soname is `liberfa.so.1` — what `README.md` §4.5 already said. Both examples
now read `/usr/lib/liberfa.so.1` and carry the one-line derivation; `.path`
names a file, so `liberfa.so.1.8.1` works too.

**3. `runtime/library.zig` promised the leap-second state is thread-local and
said this build is the reason.** The claim was that "this package's build is the
reason that last branch is not taken here: the translation step and the compile
line both define the macro chain's inputs, and `build.zig` records which branch
the chosen toolchain takes". `build.zig:158-194` says the opposite on purpose:
no `-std=` is added, `ERFA_THREAD_LOCAL` is never defined, and a target landing
on the empty arm "would compile and run without a diagnostic". The bullet now
states the branch as compiler-dialect-dependent and keeps only the
compatibility rule that survives either way — a process-global provider has a
different thread-safety contract and is not an interchangeable provider, and
`validate` cannot tell the two apart. The two follow-on claims in the same file
were corrected with it: `validate` establishes that the provider carries this
fork's leap-second state (not that it is thread-local), and the `count <= 0`
refusal message no longer says "thread-local". The same conditional wording now
replaces the unconditional per-thread claims in `zig/root.zig`'s module
documentation and `leap` namespace, and in `README.zig.md` §6; `README.md`
§4.4 and §3.4, `UPSTREAM.md`, `build.zig` and `FORK-NOTES.md` entry 22 already
stated the open position and are unchanged.

**4. Both consumer run steps dropped the arguments they document.** The consumer
program documents `--provider <path>` on its command line
(`consumer/src/main.zig:16-18`) and `zig/root.zig`'s own `consumer` step runs
the same program, but neither build forwarded `b.args`: `consumer/build.zig`
built `run_exe` with no `addArgs`, and `build.zig` forwarded `b.args` to `smoke`
two lines above and not to `run_consumer`. `zig build consumer -- --provider
<path>` therefore dropped the flag, found no `ERFA_TEST_PROVIDER`, and exited
telling the caller to pass the flag they had just passed. One
`if (b.args) |args| run….addArgs(args);` each, after each
`has_side_effects = true`.

**5. The installing cells of `verify.yml` wrote `zig-out/` into the checkout.**
Three steps ran a bare `zig build` — `native`'s Build, `c-surface`'s Build and
install, `shared`'s Build and install the shared object — and a bare
`zig build` runs the install step. Each now names an explicit `--prefix` under
the runner's own `$RUNNER_TEMP` (`erfa-default`, `erfa-static`, `erfa-shared`),
and every check that read `zig-out/` back — the default-install check, the
installed C compile, the soname and `pkg-config` check, the export-surface walk
and the shared `pkg-config` link with its `-rpath` — follows the same prefix.
The `test`, `upstream-test`, `smoke`, `check` and `consumer` cells depend on no
install step and are left without a prefix; no job, target, flag or step was
added, removed or reordered.

**Status.** `SOURCE-CONFIRMED` for every file: each claim above is a read-out of
`configure.ac`, `src/tpors.c`, `src/tporv.c`, `src/erfadatextra.h`,
`src/erfadatextra.c`, `build.zig` or `verify.yml` as written.
**`PENDING-VERIFICATION` for every gate**: no `zig`, `nix`, `devenv` or workflow
run has looked at this tree since the change, and the driver has never executed
`verify.yml` (see `README.zig.md` §9c). Item 3 changes no compiled behaviour and
item 4 changes what a caller must type, not what the build accepts.

## 20. The current graph is observed in all four modes, with a 53-cell matrix — 2026-10-05

**Scope.** Documentation only. No build file, no source file, no native byte and
no licence record changed, and no gate was run for this entry; the numbers are
read out of four existing driver receipts.

**Observed.**

- Native eight cells, `zig build test smoke install -Doptimize=<mode>
  -Dlinkage=<l> -Druntime=false -j8 --summary all`, static × dynamic crossed with
  Debug, ReleaseSafe, ReleaseFast and ReleaseSmall: exit 0 in all eight,
  `Build Summary: 25/25 steps succeeded; 61/61 tests passed`.
- Own-loaded eight cells, the same eight configurations with `-Druntime=true` and
  `ERFA_TEST_PROVIDER` naming this tree's own `liberfa.so.1.8.1`
  (`provider.kind: "own"`): exit 0 in all eight,
  `Build Summary: 26/26 steps succeeded; 61/61 tests passed`.
- The 53-cell cohort, receipt `20261004T221720228710Z-45046/erfa-53-target-8.json`,
  `source_stamp_before == source_stamp_after` (`a4ed8e98…`), `zig_version 0.16.0`,
  `mode zig-build`, `target_count 53`, `target_jobs 8`, `jobs_per_build 8`: **exit
  0**, `status: partial`, `pass 20, fail 0, build_only 33, partial 0`, every
  executed cell `tests=61`.
- The compile-only six-target `check` baseline, row `baseline-erfa-check`: exit
  0, `Build Summary: 55/55 steps succeeded`, `declared_target_count 6`, all six
  triples named, `test_pass_lines: []`, `refusal_log_lines: 0`.

**What this moves.** Entry 19's closing note — no gate had looked at this tree
since the changes above — is superseded for `test`, `smoke` and `install`. The
corrected surface, including the `vectors.s2xpv` dispatch entry §16/§17 of this
file repaired, now runs green in every optimize mode crossed with both linkages
and in the runtime-loaded shape of each. The four-mode and 53-cell rows that
`README.zig.md` §9a.2 called pending are supplied as §9a.3, and `README.md` §3.2c
carries the same four rows.

**Bounds, unchanged in kind.** Thirty-three `build_only` cells compiled and ran
nothing and are not passes; that set includes all nine NetBSD targets and
`wasm32-wasi`, so §3.4's boundaries there stand. The six-target `check` baseline
is compile-only by construction and by the receipt's `runtime_pass_claimed:
false`. `upstream-test` and `consumer` were not in the eight cells, the
loader-behaviour rows and the Windows `DEF` export list remain unexercised, and
both Nix derivations, the devenv routes, the moved-tree `pkg-config` check and
the installed-C consumer linked and run against `lib/liberfa.so` are untouched by
these receipts. Every count is bounded to the cohort's own source epoch; a later
edit to this graph is not covered by it.