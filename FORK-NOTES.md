# FORK-NOTES.md — what packaging ERFA forced, and what it is bound to

Each entry is written in the workspace's shape: **condition, symptom, cause,
fix, targets bound**, so a later wave in another directory, library or
toolchain can apply it without re-deriving it.

Statuses are `foundation-libs/AGENTS.md` §2.

Entries 1–17 were produced by reading files in the tree — mechanical counts and
cited lines — and are `SOURCE-CONFIRMED`; entries whose *fix* has landed but has
not been observed by a gate are `PENDING-VERIFICATION` and say so. Entries 18
and 19 are different in kind: both rest on **driver-observed** gate output, both
name their receipts, and both record a cause that is bounded rather than
generalised.

The gates that exist for this fork are the ones listed in `README.zig.md` §9a and
§9a.2. Nothing here is `VERIFIED` beyond what those receipts print. **Every
source gate in the 2026-10-03 list has been run against the tree as it stood
that day**: the native run passed in `Debug`, `ReleaseSafe`, `ReleaseFast` and
`ReleaseSmall` at 51/51 tests, the upstream validation suite passed in `Debug`
and `ReleaseSafe`, the six-target `check` compiled all six required targets, an
`aarch64-netbsd` `check` translated, the corrected 53-platform matrix built
every one of its 53 targets, a C program against the current install compiled,
linked and ran, `sha256sum -c UPSTREAM.sha256` was clean, and `zig fmt` over the
fork's nine Zig and ZON files changed nothing.

**That surface is no longer the tree's surface.** The contract wave of 2026-10-04
grew the typed route from 99 members to 197 and `tests.zig` from 51 tests to 60,
so the current evidence is `README.zig.md` §9a.2: one `Debug` linked run at
`12/12` steps and `60/60` tests with the facade exercise and smoke green, a
second consumer program, both upstream validation programs printing
`validation successful`, a `-Dlinkage=dynamic` install, a runtime-loaded smoke
against an explicitly named provider, and all 268 recorded upstream bytes
unchanged. **Three of the gaps that sentence named are now closed**, by the
source-bound cohort in `README.zig.md` §9a.3 and `README.md` §3.2c: the surface
runs green in all four optimize modes crossed with both linkages and in the
runtime-loaded shape of each (`25/25` steps and `61/61` tests linked, `26/26`
and `61/61` loaded, in all eight native cells each), the 53-platform matrix
exists and is green over the twenty cells it can execute (`20 pass, 0 fail,
33 build_only`, exit 0), and the runtime route has an integrated gate over the
four runtime/linkage combinations against this tree's own `liberfa.so.1.8.1`.
Thirty-three `build_only` cells are not passes, and entries 23–27 below still
record what that wave found. The package
round trip — filtered tarball, cached fetch and a consumer built from the
fetched copy — is driven and recorded **outside** this repository, in
`local://foundation-matrix-final-package-proof.json`; that record, and only that
record, is what can establish an outcome for it. `README.zig.md` §9b states that
boundary. The driver has not executed `.github/workflows/verify.yml` and no CI
result is claimed; the one place workflow material is reused is the installed-C
program, which is that job's own C source run by the driver against the current
install (entry 7).

Two of the entries are not build problems at all. They are traps in the API
that a wrapper will hit whether or not anything fails to compile. Both are the
reason the typed route is bounded rather than total.

---

## 1. "Returns `int`" is not one kind of thing, and seven functions prove it

**Condition.** A C library whose convention is `int` status, wrapped for Zig.

**Symptom.** Not a failure — a shape that compiles and then lies. 51 of the 255
declarations return `int`. Treating that as "status" would make
`eraTpors(…)` returning `2` read as an error, would make
`eraVersionMajor()` returning `2` read as a warning, and would make
`eraGetLeapSeconds` returning `37` read as a warning thirty-seven times over.

**Cause.** Measured over the four headers: of the 51 `int` returns, **44** are
signed SOFA-style statuses (`0` / positive warning / negative error), **2** are
solution counts (`eraTpors` and `eraTporv` return `0`, `1` or `2`, documented as
the number of solutions — `src/tpors.c:23-26`, `src/tporv.c:23-26`), **3** are
version numbers, **1** is an entry count whose only error is `-1`
(`eraGetLeapSeconds`, `src/erfadatextra.c:33-37`), and **1** is an entry count
(`eraDatini`, `src/erfadatextra.c:85-87`).

**Fix.** The typed layer keeps the signed integer visible in a `Status` struct
whose field is the `int`, and uses **no Zig error set at all**: an error set
cannot carry the value of a SOFA warning, and the warning's value is the
information. Each result type carries its status beside its outputs. The typed
layer touches exactly one of the seven non-status `int` returns,
`leap.getLeapSeconds`, and says in its own doc that it is an entry count, not a
warning ladder. The other six are reachable only through the raw route.

**Targets bound.** Every target. The lesson is about C return conventions, not
about a platform.

## 2. A warning is a value, and one upstream function rewrites it

**Condition.** Chaining SOFA routines that each return a status.

**Symptom.** Again not a failure — a silent loss. `eraUtcut1` calls
`eraUtctai`, and if the child's status is negative it returns `-1`, but if the
child's status is **positive it copies it through** (`src/utcut1.c:85-90`).
Chains that map everything to `-1` do exist. So the same underlying condition
can reach a caller as `+1` on one path and as `-1` on another, and a caller
that kept only a boolean would learn nothing at all.

**Cause.** SOFA statuses are signed and overloaded: positive means "worked, with
a caveat", negative means "did not work". Upstream is explicit that the two
signs are distinct (`src/dat.c:76-78`).

**Fix.** Never collapse a status to a boolean, never discard a positive one, and
never renumber it. A non-zero status is not a failure: `eraEpv00` returns `+1`
for a date outside 1900–2100 and still computes the position
(`src/epv00.c:22-24`), and `eraPlan94` returns `+2` for non-convergence and
still returns a position (`src/plan94.c:29`).

**Targets bound.** Every target.

## 3. Error results are sentinels, and every call leaves a different one behind

**Condition.** A wrapper that wants to say "this call failed".

**Symptom.** The obvious test — "is the result NaN?" — never fires, because
nothing in this tree returns NaN on error. `eraGc2gd` writes `-1e9` into all
three outputs (`src/gc2gd.c:76-78`); `eraGd2gc` zeroes the vector "in all error
cases" (`src/gd2gc.c:48-49`); `eraEform` writes `a = f = 0.0` before returning
`-1` (`src/eform.c:87-89`); `eraCal2jd` **still writes both outputs** when it
returns `-3`, which upstream labels "bad day (JD computed)"
(`src/cal2jd.c:22-24`). A consumer that does not check the status receives
`-1e9` metres of height and has no way to know.

**Cause.** SOFA's error convention is "status carries the failure; outputs carry
a defined residue", and the residue is per-routine, not per-library.

**Fix.** Check the status, and state per function what a rejected input leaves
behind. Do not invent a single sentinel, and do not validate inputs upstream
does not validate: `eraGd2gc` performs no validation on longitude, latitude or
height (`src/gd2gc.c:45`) and `eraApco13` accepts even unlikely input
(`src/apco13.c:125`).

**Targets bound.** Every target.

## 4. The leap-second table is borrowed, and the setter retains the caller's pointer

**Condition.** Wrapping `eraGetLeapSeconds` / `eraSetLeapSeconds`.

**Symptom.** The failure mode is not a compile error; it is a dangling pointer.
`eraGetLeapSeconds` returns upstream's own active table with no copy
(`src/erfadatextra.c:46-47`), and `eraSetLeapSeconds` stores the **caller's**
pointer with no copy and no checks — its own note reads "*No* sanity checks are
performed" (`src/erfadatextra.c:61`), with `count <= 0` resetting to the
built-in table (`src/erfadatextra.c:56-58`). A wrapper that presented the getter
as owned data, or that freed the borrow, or that let a borrow outlive a
replacement, would be wrong in a way no compiler catches.

**Cause.** The pair is an experimental, user-replaceable hook — upstream's own
words at `src/erfaextra.h:11-16`. Its lifetime rule is entirely the caller's.

**Fix.** Present the getter's result as a borrow that aliases upstream storage;
assert no ownership; state that a borrow is invalidated by a replacement or a
reset **on the thread that made it**; and document that after a setter call the
caller owns the lifetime of whatever it installed — it must stay alive and
unmodified for as long as any `eraDat` call can run on that thread, because
nothing copies it. There is no deinitialisation step, because there is no
allocation anywhere in the core.

**The index boundary, which the signature does not show.** There is a second
trap in the same pair and it is worse than the dangling pointer, because a
correctly sorted, correctly allocated replacement table can still be wrong.
`eraDat` selects the preceding entry by **position** and then applies the
pre-1972 drift correction by that same position:

```c
   for (i = NDAT-1; i >=0; i--) {                        /* src/dat.c:231-233 */
      if (m >= (12 * changes[i].iyear + changes[i].month)) break;
   }
   if ( i < 0 ) return -5;                               /* src/dat.c:235-236 */
   da = changes[i].delat;                                /* src/dat.c:239     */
   if ( i < NERA1 ) da += (djm + fd - drift[i][0])
                           * drift[i][1];                 /* src/dat.c:241-242 */
```

`NERA1` is 14, derived from the 14-row `drift` table (`src/dat.c:129-147`).
Three consequences, each silent:

- `i < 14` is a **position**, not a year, so a drift rate is added to whatever
  row happens to occupy that slot;
- the scan runs from the end and stops at the first entry whose
  `12*iyear + month` is at or below the date, so the table must be in
  ascending date order or the "preceding" entry is not the preceding one;
- `changes[0]` is the pre-UTC boundary — `if (iy < changes[0].iyear)
  return 1;` (`src/dat.c:222`) — so a table that starts in the modern era
  makes every historical date return the warning `+1` with a zero ΔAT.

**Fix for the second trap.** A valid replacement is the **complete built-in
table with new rows appended**, never a short modern table. The first fourteen
entries must stay the built-in ones, 1960-01-01 through 1968-02
(`src/dat.c:151-164`), and appended rows go at the end in ascending
`12*iyear + month`. **A two-row modern table is not valid even though it is
sorted.** A caller builds one by borrowing the built-in table, copying all of
it into storage it owns, appending, and handing *that* to the setter — the
pattern this package's own test uses (`tests.zig:415-443`), which also proves
the retention rather than asserting it by writing `40.0` into caller storage
between two calls and reading `40.0` back (`tests.zig:433-435`).

**A test that asserts an unreachable branch will manufacture the wrong fix.**
An earlier version of this package's own test asserted `−5` for a date before
a replacement table's first entry. `-5` is upstream's underflow guard
(`src/dat.c:236`) and it is pre-empted by the pre-UTC warning at
`src/dat.c:222`, which returns first. Asserting it pushes the author toward
"fixing" the table so the `-5` becomes reachable — which is exactly the
"short modern table" mistake above. Re-read entry 15 whenever a status looks
unreachable.

**Targets bound.** This one is **version-bound**. At this pin the table
pointer and its length are `ERFA_THREAD_LOCAL`
(`src/erfadatextra.c:22-23`), so a replacement or reset **on another thread**
does not invalidate a borrow, and "the active table" is per-thread. At the
`v2.0.1` tag the same two variables were process-global plain `static`
mutable state — a data race in any threaded host. The per-thread clause is
therefore a property of this pin and must be re-checked on every re-pin, not
carried forward as a general truth. On a target where the `ERFA_THREAD_LOCAL`
chain falls through to its empty definition (`src/erfadatextra.h:38-50`), the
state silently becomes process-global again and the whole clause changes.

## 5. `eraDtf2d` can return a fraction outside `[0, 1)`

**Condition.** Treating a two-part date as a day number and a fraction.

**Symptom.** A clamp, a re-split, or an assertion turns a correct result into a
wrong one. `eraDtf2d` sets `*d1 = dj; *d2 = time;` (`src/dtf2d.c:143-148`),
where `time` divides the seconds of the day by a `day` that has been lengthened
on a leap second (`src/dtf2d.c:118-120`), so `d2` can reach or exceed 1.
The routine says so: the end-of-day limit becomes 61.0 on a leap second, or 59.0
for a negative leap (`src/dtf2d.c:58-61`), and it returns `+2` for "time after
end of day" while still producing the value.

**Cause.** UTC is not representable as an unambiguous Julian Date during a leap
second, so ERFA uses a *quasi-JD* convention: a UTC day is 86399, 86400 or
86401 SI seconds, including the 1960–1972 mini-leaps
(`src/dtf2d.c:50-56`). Upstream is explicit that only for the continuous scales
TAI, TT, TCG, TCB and TDB is `d1 + d2` strictly a Julian Date, and that for UT1
and UTC "the difference between two such results cannot be interpreted as a
precise time interval" (`src/dtf2d.c:67-72`).

**Fix.** Pass the value through. Never normalise, never clamp, never re-split.
Where a two-part date is needed, use a type whose contract states that the
**sum** is the value and that the apportionment is arbitrary — upstream's own
point, with four equivalent splits of JD 2450123.7 in
`src/jd2cal.c:33-42` and Kahan–Neumaier compensated summation so the result
does not depend on which split was used (`src/jd2cal.c:44-46`).

**Targets bound.** Every target.

## 6. The scale argument is compared with `strcmp`, so it is exactly `"UTC"`

**Condition.** Calling `eraDtf2d` / `eraD2dtf`.

**Symptom.** Passing `"utc"`, `"Utc"` or `"UTC "` silently takes the non-UTC
path — no error, a different answer, because the comparison is
`! strcmp(scale, "UTC")` (`src/dtf2d.c:99`, `src/d2dtf.c:97`).

**Cause.** Upstream's API takes a `const char *` and does an exact match; only
the upper-case string enables leap-second handling.

**Fix.** The typed layer takes an enumeration, not a string, so the case
mistake cannot be written. The raw route keeps upstream's contract and its
documentation.

**Targets bound.** Every target.

## 7. `erfa.h` does not include `erfam.h`

**Condition.** Installing and translating the public headers.

**Symptom.** A consumer that includes only `<erfa.h>` and then uses `ERFA_DJM0`
fails to compile, and the obvious fix — "just include erfam.h too" — is the right
fix, but only if the installed header set actually contains both. Upstream made
this explicit: from 2.0.0 one has to include `erfam.h` explicitly
(`README.rst:66-68`). Measured: 107 of the 249 core `.c` files include
`"erfam.h"` themselves and 142 do not.

**Cause.** A deliberate upstream change, so the constants do not leak into every
translation unit.

**Fix.** Translate and install **all four** headers, not just `erfa.h`; keep
`erfa.h` and `erfam.h` separate in the translation so the upstream
relationship survives; and make the installed-C gate include both, which is the
only way a missing install actually fails.

**Targets bound.** Every target. Status `VERIFIED`: the four public headers are
installed, translated separately, and the installed-C program
`#include`s **all four** — `erfa.h`, `erfam.h`, `erfaextra.h` and
`erfadatextra.h`, the last being the one no other header pulls in — so a missing
install fails that check instead of passing it
(`local://foundation-matrix-erfa-installed-c-current-compile.log`,
`-run.log`, exit 0 both). That program is the **same C source the
installed-C job in `.github/workflows/verify.yml` carries**, taken from that
job's heredoc and compiled and run unchanged by the driver, outside CI, against
the install this tree produces. The driver did not execute the workflow; see
`README.zig.md` §9c for where that line sits.

## 8. Exactly one generated header, one consumer, and it is included by bare name

**Condition.** Upstream generates `config.h`; this package must not run
autotools.

**Symptom.** One translation unit fails to parse. `src/erfaversion.c:15-17`
wraps `#include <config.h>` in `#ifdef HAVE_CONFIG_H`, and that include is by
**bare name**, so the directory has to be reachable at translation time. An
installed header is not on the compile line either, so include paths have to be
on both.

**Cause.** Upstream's `configure`/`meson` puts the build directory on the path
for free. A package that writes the header itself has to reproduce that on two
lines.

**Fix.** Write `config.h` as a deterministic build step from five recorded
values — `PACKAGE_VERSION "2.0.1"`, `PACKAGE_VERSION_MAJOR 2`, `_MINOR 0`,
`_MICRO 1`, `SOFA_VERSION "20231011"` (`meson.build:3,24-29`,
`configure.ac:5,23`, `m4/erfa-numver.m4`) — define `HAVE_CONFIG_H`, and put the
generated directory on the compile line **and** the translation line.
`src/erfaversion.c` is the only consumer, so the exposure is one translation
unit, but it is the one that decides whether the build works at all.

**Targets bound.** Every target; and the values are **version-bound** — they come
from upstream's own `meson.build`/`configure.ac`, so a re-pin that moves the
package version or the SOFA version must update them.

## 9. A "dubious year" cliff is baked into the source with a date on it

**Condition.** Any date far enough in the future.

**Symptom.** `eraDat` returns the **warning** `+1` for every call with a year
of 2029 or later, because `src/dat.c` contains `if (iy > IYV + 5) j = 1;` with
`enum { IYV = 2023 }` (`src/dat.c:126`). The result is still computed and the
status is still only a warning, so a consumer that treats non-zero as failure
breaks on a date it never tested.

**Cause.** Leap seconds cannot be predicted in advance, so upstream guards
against gross error by warning for years more than five past the release year
(`src/dat.c:69-74`), and the release year is a constant in the source.

**Fix.** Do not hide it and do not paper over it. Document the threshold and the
date, keep the warning a warning, and update it the way upstream does when a
leap second is announced — by re-pinning, because the table, `IYV`, the "Latest
leap second" comment and the "This revision" comment are all upstream-owned
bytes covered by `UPSTREAM.sha256` (`src/dat.c:14-42` states the four-step
procedure).

**Targets bound.** Every target; the **date** is version-bound. As of
2026-10-03 the threshold is three years out and the table's last entry is
2017-01-01 at ΔAT = 37.0 s.

## 10. One licence, five files that say they are not derived, and one file that
says both

**Condition.** Recording per-file terms for a BSD-3 tree.

**Symptom.** A flat "BSD-3-Clause" label is true of the *terms* and false of
the *attribution*. Measured over the 255 files in `src/`: 250 carry the SOFA
derivation statement and the full BSD text inline, 4 declare "This file is NOT
derived from SOFA sources" with no inline text
(`src/erfaextra.h`, `src/erfadatextra.h`, `src/erfaversion.c`,
`src/erfadatextra.c`), and **one declares both** — `src/t_erfa_c_extra.c:6`
says not derived, and its last 62 lines carry the SOFA-derivation footer with
clause 3 at `t_erfa_c_extra.c:163-166`.

**Cause.** Upstream added non-SOFA extension files over time and did not always
remove the inherited footer.

**Fix.** Itemise by path and line in `NOTICE.md`; do not repair it, because
repairing it means editing an upstream byte and this package patches no native
source. Both texts are BSD-3, so nothing is unsatisfied — but a record that
flattened the tree would have missed three of the five.

**Targets bound.** This pin. Re-measure on re-pin; the counts here are measured,
not assumed.

## 11. Upstream's CI is upstream's, and this package's build is not upstream's

**Condition.** Shipping upstream's `.github/workflows/ci_workflows.yml`.

**Symptom.** A file in the tree that drives `autoreconf`, `configure`, `make`,
`make check`, `make distcheck` and `meson dist` on hosted runners. Nothing in
this package runs any of those. If it were wired into this repository's gates it
would be a gate for a build system this package does not use, on a maintainer's
infrastructure.

**Fix.** Keep the file as retained upstream material (digest in
`UPSTREAM.sha256`), do not retarget it, and put this fork's own gates in a
separate `verify.yml` that names only this repository.

**Targets bound.** Every target.

## 12. There is no system mode, so there is no system gate

**Condition.** A package that would normally offer
`b.systemIntegrationOption`.

**Symptom.** None — this is recorded so that its absence is not later read as an
unmet obligation or as a passed gate.

**Cause.** This wave fixes the source pin and the bounded contracts; a system
mode would need the real selected installed headers translated, and
`erfa.pc.in` alone is not that.

**Fix.** Document **NOT APPLICABLE** for this wave. `erfa.pc.in` and `erfa.pc`
are retained and unused. A later wave that adds the mode must translate the
real selected headers, must not ship bundled headers against an older installed
library, and must not quietly relax the pin.

**Targets bound.** This wave only.

## 13. An upstream ignore rule can swallow an upstream source file

**Condition.** Keeping upstream's `.gitignore` verbatim and adding this fork's
own ignore entries to the same file.

**Symptom.** Two problems that pull in opposite directions. Upstream's file
ignores `/m4/` — but `m4/erfa-numver.m4` is not a build artefact, it is upstream
source that records the `PACKAGE_VERSION` major/minor/micro split this package
reproduces in its generated `config.h`, and this package ships and digests it.
Delete the pattern to fix that and a future `git add -A` drops an upstream file
that the integrity gate checks. Keep the pattern and the file stops being
trackable. Separately, Zig's `.zig-cache/`, `zig-out/` and `zig-pkg/` have to be
ignored somewhere.

**Cause.** Upstream's ignore list is tuned for a tree that never contains a Zig
build, and its `/m4/` rule predates this fork's need to carry the macro file.

**Fix.** Re-inclusion, not deletion. All 24 upstream patterns stay
byte-for-byte and in their original order; the fork appends `!/m4/` and
`!/m4/erfa-numver.m4` and then the six Zig output patterns. Because the file is
now intentionally non-identical, it is **deliberately absent from
`UPSTREAM.sha256`** (268 records instead of 269) and from the unmodified-paths
diff in `verify.yml`, and `verify.yml` checks the deviation as a deviation:
`.gitignore` must be absent from the manifest, the manifest must carry the
deviation note, `NOTICE.md` must name the file, and all 24 upstream patterns
must still be present as exact lines in their original order. Recording the
edited file at the upstream digest would make the integrity gate fail on a known
deviation; re-recording the digest over the edit would hide it.

**Targets bound.** Every target. The upstream digest is
`e84d726d8ebf4331d491995ff5ff0a49a64f0b8740e29d21191d307eb05e793d` and must be
re-measured, not remembered, on any re-pin.

## 14. Where a variable lives is decided by its enclosing brace, not its neighbours

**Condition.** Reading C to decide how long a value persists.

**Symptom.** A declaration sitting among `static` tables can be read as
file-scope storage when it is not, and the whole conclusion inverts. In
`src/dat.c` the lines `static const double drift[][2]` (`:129`) and
`static const eraLEAPSECOND _changes[]` (`:150`) are inside the *same compound
block* as a later pair of declarations without `static`; one is function-body
storage that initialises once, the other is an automatic local re-initialised on
every call. The contrast is visible in the same twenty lines, and upstream does
write `static` when it means file-scope — the absence of it is the signal.

**Cause.** Line-scoped reading. The decisive fact is the brace that opens the
enclosing block, and that is a different line from the one the declaration is
on.

**Fix.** Before claiming storage duration, find the enclosing `{` and check the
brace depth at the declaration; then compare with a neighbouring declaration in
the same block that *does* carry `static`. Supporting greps do not substitute:
the absence of a token such as a TLS macro says nothing about how long a local
lives.

**Targets bound.** Every language with block scope and every target. The lesson
is about reading, not about this library, and it applies wherever a wrapper has
to state an upstream lifetime contract.


## 15. A status branch is a behaviour only if an argument reaches it

**Condition.** Wrapping a C routine whose status ladder has more than one
negative status, or guarding a divisor.

**Symptom.** Three failures with one shape — a test asserts a status the code
cannot produce. `eraCal2jd` returns `-1` and `-2` *before* writing either output
and `-3` *after* writing both (`src/cal2jd.c:68-84`); the facade decided that
with a single inequality, so `-3` was published as "absent" and `-1` was
published from two uninitialised doubles. `eraDat`'s table search has an
underflow guard `-5` (`src/dat.c:236`), but the pre-UTC test at
`src/dat.c:222` returns the warning `+1` first, so a date before a replacement
table's first entry never reaches `-5`. `eraGd2gce` guards
`d = cos(phi)^2 + w^2 sin(phi)^2 <= 0` (`src/gd2gce.c:73-74`), a sum of
non-negative terms, so no finite argument drives `d` to zero and `-1` is
unreachable.

**Cause.** Reading a guard as a reachable outcome. A guard answers "what would
be checked if this could fail", not "what a caller can observe"; the branch that
reaches it has to be read too, and it is usually earlier in the function.

**Fix.** For each status, name the line that returns it and the line the
outputs were last written on, and publish exactly that. Test the statuses
inputs can produce; document an unreachable one as unreachable rather than
manufacturing an input for it.

**Targets bound.** Every target. The rule is about reading one C function, and
it is what stops a wrapper from publishing undefined doubles or a test from
asserting an impossible status.

## 16. A wrapper's parameter name and units are the contract

**Condition.** A facade that forwards positional C arguments.

**Symptom.** Four documented inputs that do not say what upstream means.
`eraEors`'s second argument was named an arcsecond-to-radian scale and is the
CIO locator `s` in radians, and its result is the equation of the **origins**,
ERA - GST, not the equation of the equinoxes (`src/eors.c:14-27`); `eraApco13`
and `eraAtco13` return that same quantity. `eraLd`'s fifth argument was
documented as a companion mass and is the observer-to-body **distance in au**,
which upstream divides by (`src/ld.c:14-20,87-89`). The whole `lt*` family
takes an absolute TT Julian epoch and subtracts 2000.0 internally
(`src/ltpecl.c:13`, `src/ltpequ.c:84`), and `eraEpb`/`eraEpj` return the year
plus fraction counted from 2000.0 (`src/epj.c:53`), so "days from J2000.0" was
wrong in both directions.

**Cause.** Naming the parameter from the shape of the surrounding call rather
than from the `Given:` block of the routine it forwards to.

**Fix.** Take each scalar's name and unit from the source file's own
documentation, and re-read it whenever a doc is written. A caller who follows
the facade's name instead of upstream's gets a wrong number, not an error.

**Targets bound.** Every target; the defect lives in the source text and is
invisible to every gate.

## 17. Publish the members a routine writes, not the record it writes them into

**Condition.** A C API that fills a caller-supplied context struct.

**Symptom.** `eraApio13` hands back an `eraASTROM` whose `pmt`, `eb`, `eh`, `em`,
`v`, `bm1` and `bpn` were never assigned — upstream writes them into the
record the *caller* already had, which is what lets `eraAtciq` consume it later
(`src/apio13.c:192-193`, `src/atciq.c:75-84`). `eraASTROM.phi`
(`src/erfa.h:31`) is assigned by nothing in `src/` at all, so even
`eraApco13`'s record carries one member that does not exist.

**Cause.** Treating "the record after the call" as "the computed result".

**Fix.** Name the members the routine assigns, copy those out, and keep the raw
record on the `c` route for anyone who needs to prefill it. Zeroing the
unwritten members invents values upstream never produces.

**Targets bound.** Every target.

## 18. A C ABI boundary is where a Zig backend bug shows up, and only the consumer can choose the backend

**Condition.** Calling a wide C routine from Zig — here `eraApco13`, twelve
`double` scalars and two pointers, `src/erfa.h:80-83` — with the **default**
self-hosted backend, in `Debug`.

**Symptom.** The status comes back wrong, and wrong in the worst way: as a
**positive** value. Observed on 2026-10-03 by two runs of one probe program
that differ only in a flag:

| | default backend | `-fllvm` |
|---|---|---|
| `eraApco13`, raw `erfa.c`, valid 2013 date `2456384.5 + 0.969254051` | `1` | `0` |
| `eraApco13`, typed `erfa.rotation.apco13`, same date | `1` | `0` |
| `eraApco13`, raw, unacceptable date `−1e10 + 0` | `1` | `−1` |
| `eraApco13`, typed, same date | `1` | `−1` |
| `eraUtctai`, both dates, both runs | `0` / `−1` | `0` / `−1` |

Receipts: `local://foundation-matrix-erfa-boundary-isolation.log` (exit 0) and
`local://foundation-matrix-erfa-boundary-llvm-discriminator.log` (exit 0),
Zig 0.16.0, `-ODebug`, native target. The two argv lines are identical apart
from a leading `-fllvm`, and they link the **same**
`…/erfa/local/o/3fc96734ab923532bbeb6b9530bfc70e/liberfa.a`, the same
`zig/root.zig` and the same `translate.zig`.

`+1` is upstream's *dubious year* **warning** (`src/dat.c:69-78,225`): it still
computes, and 2013 is far from the 2029 threshold. A caller that treats
non-zero as failure rejects a good date; a caller that treats a positive status
as success accepts a date of `−1e10`. Both are wrong answers, delivered
silently.

**Cause.** **Not established, and deliberately not claimed.** What is
established is only the negative space: the C archive is byte-identical across
the two runs, the facade's own logic is identical, and the raw route and the
typed route — two completely different Zig call shapes — report the *same*
wrong value. `eraUtctai`, three arguments, in the same probe and the same
runs, is correct. So the failure is in the Zig front end's handling of that
call, and nothing narrower. This package did not bisect it, filed no issue,
and asserts no mechanism.

**Fix.** `.use_llvm = true` on every Zig root that reaches this package, and
`-fllvm` where the root is a command line. In-tree that is `build.zig` (the
`addTest` root and the exercise, smoke and consumer executable roots) and
`consumer/build.zig`. **No native source is patched and no shim is added** —
`src/apco13.c` and `src/erfa.h` are covered by `UPSTREAM.sha256` and stay as
upstream wrote them, and there is deliberately no argument-reordering wrapper
or `#define` to paper over it.

**The part that is easy to get wrong: a module cannot enforce this.** The
backend is a property of the `addExecutable`/`addTest` root, which belongs to
whoever owns the build. A published module — even one that carries its
library, its include paths and its libc requirement — has no authority over
an external consumer's root and cannot set a flag on it. So the fix is only
half a fix: **every external consumer has to state `.use_llvm = true` itself**,
and the package's obligation is to say so loudly, in `README.zig.md` §1a, in
the module's own build, and in `consumer/build.zig`. A package that documents
the requirement but does not also demonstrate it in its own consumer has left
the next consumer to discover the bug.

**How this showed up before it was isolated.** The first native Debug run of
the full surface was red at `38/51`
(`local://foundation-matrix-erfa-before-complete-runtime.log`). Most of those
thirteen were genuine source-reading defects — unwritten doubles published for
`cal2jd`'s `-1`, an equation of origins labelled as an equation of the
equinoxes, a `-5` asserted where `src/dat.c:222` returns `+1` first, a `-1`
asserted for a routine that validates nothing (entries 15, 16, 17). One of
them, `rotation: an unacceptable date leaves the astrometry outputs absent —
expected -1, found 1`, had exactly this signature. Splitting "the facade is
wrong" from "the call is wrong" needed the two-run discriminator above, and
until that discriminator exists neither explanation may be asserted.

**Targets bound.** **Every mode, and every target that can execute the suite —
and the rule is still narrow.** The discriminator itself is Zig 0.16.0,
`-ODebug`, native target, these two inputs, these two routes; it says nothing
about the other 254 declarations. What the later gates add is that the
package-wide flag **works in every mode**: `Debug`, `ReleaseSafe`,
`ReleaseFast` and `ReleaseSmall` each run all 51 tests green, and one of those
51 is the `eraApco13` rejection this defect breaks
(`README.zig.md` §9a). It does not add a cause, and the cause is still not
established — no gate here shows *why* the default backend returns the wrong
status. What a foreign target adds is bounded the same way: 20 platforms of
the 53-platform run execute all 51 tests green with `.use_llvm` set, and 33
compile only, which proves nothing at run time. Because the rule is narrow it
still generalises in the shape a later wave needs: *when a C ABI boundary is
involved, the backend choice belongs to the consumer, the module cannot force
it, and a package that depends on a specific backend must say so in its
published contract and demonstrate it in its own consumer.* The requirement
binds **Zig roots only**: a pure C program linking `liberfa.a` has no backend
to choose, and the installed-C program in §9a is compiled and run with no
backend flag at all.

## 19. NetBSD's C library breaks the translation route twice — once in a macro, once in a typedef

**Condition.** Translating one aggregate header that reaches exactly one system
header — `math.h`, via `erfa.h:15` — for a target whose libc disagrees with the
bundled C front end. It disagreed twice, in two different ways, and only the
first was visible from the outside.

**First symptom.** Nine targets fail, and only nine. The 53-platform run
*before the route landed* records `build_failed` on `aarch64-netbsd`,
`aarch64_be-netbsd`, `arm-netbsd`, `armeb-netbsd`, `mips-netbsd`,
`mipsel-netbsd`, `powerpc-netbsd`, `x86-netbsd` and `x86_64-netbsd`, and on no
other target — **five errors at `math.h:607`**, with the C archive itself
compiled. Receipt
`local://foundation-matrix-erfa-cross-original-summary.json`, run id
`20261003-182240-52530-15219`, overall `status: fail`, `exit_code 1`. That run is
history; the corrected one is in "Evidence, both stages" below.

**First cause.** `generic-netbsd/sys/cdefs.h:431-432` routes `__END_DECLS`
`__BEGIN/END_PUBLIC_DECLS`, which `:411-416` defines as `extern "C"` framing
around `_Pragma("GCC visibility push(default)")` and
`_Pragma("GCC visibility pop")`. `<math.h>` closes every declaration block with
`__END_DECLS`, so every NetBSD translation drags two `_Pragma` operator
invocations in. Aro destringizes each into a `#pragma` line and hands it to the
parser as C, which is not valid there. Every other C library in this matrix
spells the macro as plain tokens, which is why the failure is confined to one
OS family and one header.

**Fix.** `zig translate-c` parses C with **Aro**, which preprocesses as well as
parses, so the aggregate header can be read either way round. `build.zig` now
selects per target: Aro preprocesses `zig/translate.h` for itself on every
target but NetBSD (unchanged), and on NetBSD `zig cc -E -dD` — the same pinned
compiler, given `-target <triple>` when the target is not native, with the same
include path, the same generated `config.h` directory and a `-MD`/`-MF`
dependency file — expands it first, and Aro parses the result. The condition is
the **OS tag**, not a list of nine triples, because the family shares one
header and one cause and a list would silently stop covering the next
architecture.

**Why `-dD` and not a plain `-E`.** Without it the expansion carries no macro
definitions and `pub const c` loses them. `erfam.h` is almost entirely macros,
so `ERFA_DJM0`, `ERFA_DAYSEC` and `ERFA_WGS72` would drop out of the
translation and a C caller reading them as macros would stop getting constants.
Nothing is stubbed, narrowed or renamed on either route; the aggregate is read
with every `#include` resolved, every conditional settled and every definition
kept, and all four public headers and all 35 macros still reach Zig.

**The second observation, which the first one could not have found.** With the
route in place, `zig build check -Dtarget=aarch64-netbsd -j2 --summary all`
still failed: `Build Summary: 7/11 steps succeeded (3 failed)`, three of the
Zig-root steps red on `use of undeclared identifier '__int128_t'` at
`local://foundation-matrix-erfa-netbsd-preprocess-check-r1.log:3-6`, while the C
archive and both upstream validation programs compiled. **Symptom shape worth
noticing: three failures with one cause.** The library, both `t_erfa_c*`
programs and the `preprocess` step were green, and only the three Zig roots that
import the translated module were red — so "the fix works" was not a conclusion
anyone could draw from the route landing.

**Second cause.** `generic-netbsd/math.h:21` opens `<sys/cdefs.h>`, `:76` opens
`<machine/cdefs.h>`, and `generic-netbsd/arm/cdefs.h:62-63` spells
`__ALIGNBYTES` as `sizeof(__int128_t) - 1` on the `__ARM_PCS_AAPCS64` branch —
the branch `aarch64-netbsd` takes, because `__ARM_PCS_AAPCS64` is one of the
compiler's own predefines for AArch64. `-dD` is what exposes it: the spelling
survives into the expansion, and **no header declares the typedef**, because
Clang declares `__int128_t`/`__uint128_t` next to `__int128` itself rather than
in a libc header. Aro — and `zig translate-c` reading its output — then produced
`pub const __ALIGNBYTES = __helpers.sizeof(__int128_t) - @as(c_int, 1);` naming
an identifier nothing in the file declares.

**Second fix, and what it is not.** Three lines in `zig/translate.h`, ahead of
the four includes: under the compiler's own capability macro
`__SIZEOF_INT128__` — the macro Clang defines exactly when the target has that
type — `typedef __int128 __int128_t;` and
`typedef unsigned __int128 __uint128_t;`. That declares the **compiler's own
128-bit integer extension**, which is the declaration the expansion was
referring to and which no libc header repeats. It is **not** a patch to any
native file, not a macro redefinition, and not a re-scoping: **no `.c` and no
`.h` upstream file is touched.** It is inert where it is not needed —
`x86_64-netbsd` spells `__ALIGNBYTES` as `sizeof(long) - 1`
(`x86_64-netbsd-none/machine/cdefs.h:6`) and needs none of it, the 32-bit
NetBSD targets leave the guard false, and a target with no `__int128` declares
neither typedef. Where a header *does* declare them, the typedef lands on the
same declaration. The convention is the one `pcre2` and `lmdb` already carry in
this workspace.

**What the second fix did not change.** Nothing else of the C library is
restated: `__ALIGNBYTES` itself and every other macro and declaration NetBSD's
headers contribute stay exactly as the target's own headers spell them, and
`__int128_t` is spelled the way those headers spell it.

**Evidence, both stages.** `local://foundation-matrix-erfa-netbsd-preprocess-check-r2.log`
— `Build Summary: 11/11 steps succeeded`, with `preprocess erfa translate.h`
sitting under the translation. Then the corrected 53-platform run, run id
`20261003-194646-57707-28197`, builds **all nine** NetBSD targets:
`aarch64-netbsd`, `aarch64_be-netbsd`, `arm-netbsd`, `armeb-netbsd`,
`mips-netbsd`, `mipsel-netbsd`, `powerpc-netbsd`, `x86-netbsd` and
`x86_64-netbsd` each report `build: pass` with `run: unavailable` and
`reason: runtime_unavailable` — `build_only`, not `pass`. **Compiled is not
executed:** none of the nine has ever been run, and no claim about NetBSD
runtime behaviour is made.

**Targets bound.** Every target takes one of the two routes, and **both are
observed**. The `.aro` route is unchanged from before the fork touched
translation and is exercised by the six-target `check` (`55/55 steps`, all six
required `-Dtarget` triples); the `.preprocessed` route is exercised by
`zig build check -Dtarget=aarch64-netbsd` (`11/11 steps`) and by the nine
NetBSD rows of the corrected 53-platform run, all `build: pass`. Neither claim
is a runtime claim: the six-target `check` runs nothing, and the 33
`build_only` rows in that run — the nine NetBSD ones among them — had no
runner. The lesson generalises in two parts: *when the translator and the
target's libc disagree about one macro, check the OS, not the triple list, and
let the target's own preprocessor do the job the bundled front end cannot — but
keep the flag that preserves macros, or the translation loses them silently*;
and *when a target header names a type the compiler predeclares rather than a
header declares, restate the compiler's own declaration in the file the
translator reads, under the compiler's own capability macro — and expect a
re-gate to find a second cause the first gate could not see.*

## 20. Relocating a README is a copy, not a rename, and the manifest's path set is the rule

**Condition.** A fork that has to publish its own README at `README.md` while
upstream's own README lives at a **different** path — here `README.rst`, in
RST, so there is no collision and no rename to perform — and an integrity
manifest whose stated rule is that its path set is the pinned commit's own file
list rather than a directory walk.

**Symptom.** Two plausible moves, both wrong. *Rename* `README.rst` →
`README.upstream.md` deletes a retained upstream file that the manifest digests
at `UPSTREAM.sha256:60` and that its own header counts among the 269, so
`sha256sum -c` fails on a file that was never edited. *Add* the copy to the
manifest and the manifest's own rule breaks: its path set stops being the pin's
file list, which is the only thing that stops a fork-authored file from
entering it by accident, and the same digest is now recorded twice for the same
bytes.

**Fix.** Copy, never move, and keep the digest in prose. `README.rst` stays
byte-identical and digested at its own path. `README.upstream.md` is a
byte-for-byte copy whose digest is stated in three places that must be updated
together — `UPSTREAM.md` §2, `NOTICE.md` §3a and `FORK-LICENSE.md` §4 — plus the
driver's extraction receipt
(`local://foundation-contract-upstream-readme-proof.json`, entry `erfa`).
`sha256sum README.upstream.md` is then a check a reader can run with no new
tooling, which is the actual goal: integrity coverage, not manifest symmetry.

**Targets bound.** The manifest's path set is the pin's own file list, by
design and by its own header. Anything outside that list — a preserved copy, a
generated header, a fork file — is out of scope for `sha256sum -c` by
construction, and the honest substitute is a recorded expected digest plus a
receipt, never a manifest line. The same rule applies to any future preserved
copy of a carried upstream file. Generalises as: *when you duplicate upstream
material to satisfy a relocation, do not widen the manifest to cover the copy;
record the digest where a reader will look for it and keep the manifest's
invariant intact.*

## 21. Two linkages are one derivation with a parameter, and the preserved default is the absence of a flag

**Condition.** A build graph that hard-codes one artefact kind — `.linkage =
.static` — and a packaging requirement for both a static and a shared output of
the same sources.

**Symptom.** Two derivations that differ only in one argument, or one
derivation per kind, or a `defaultPackage` that quietly picks the other kind
from the existing default. Each of those makes the SDK's existing linkage
policy unknowable from the package. A subtler variant: writing the derivation
to pass `-Dlinkage=static` explicitly for the static variant "so it states its
intent". That is redundant **and** fatal if the option does not exist yet —
Zig's build runner rejects an unrecognised `-D`, so the static package, which
is the one with no reason to need the option at all, becomes the variant that
cannot build.

**Fix.** One source-only derivation in `package.nix`, parameterised by
`linkage`, consumed by `flake.nix` and `devenv.nix` through `pkgs.callPackage`.
`static` passes **no** flag, because that is exactly what `zig build` already
does; `shared` passes `-Dlinkage=dynamic`. The precondition that `shared`
implies — the option must exist in `build.zig` — is stated in `package.nix`, in
the devenv script that builds it, and in `README.md` §3.3, rather than being
absorbed by a fallback that guesses. `flake.nix`'s `default` is the SDK's own
policy. "Static" is stated as a static *library artefact* everywhere, with no
wholly-static-executable claim.

**Targets bound.** The rule that the preserved default is the **absence** of a
flag is specific to a graph that hard-coded its linkage before any option
existed. A graph whose default is `.dynamic` on some targets and `.static` on
others — `pcre2` here — must pass its own default explicitly or the parameter
is a lie. Either way the invariant is the same: *the derivation's default and
the SDK's default must be the same value, and a packaging parameter must never
become the place where that value is decided.*

## 22. The thread-local state a library keeps may not be an exported symbol at all

**Condition.** A C library whose mutable global state is declared
`static <TLS-SPECIFIER>` at file scope — here `static ERFA_THREAD_LOCAL
eraLEAPSECOND *changes;` and `static ERFA_THREAD_LOCAL int NDAT;` at
`src/erfadatextra.c:22-23` — and a consumer that reaches that state through
accessor functions.

**Symptom.** A design that assumes exported data symbols exist to be read by
address. They do not: **internal linkage means these two objects are in no
symbol table at all**, in a static archive, a shared object or a loaded image.
Any plan that says "read the leap-second table's address from the image" is
describing something that cannot be done, and a plan that does not say how it
gets the table is describing something that silently cannot work. The
thread-local half is worse: the accessor's own out-parameter yields **the
address of a thread-local variable** (`*leapseconds = changes;` at
`src/erfadatextra.c:46`), so the value a caller reads back is per-thread, and a
replacement installed on one thread is not visible from another.

**Fix, in the documentation this package controls.** State the three facts
where a caller will meet them rather than in a portability appendix: the state
is per-thread where `ERFA_THREAD_LOCAL` selects a real branch and
process-global on the empty branch, which is not knowable from a compile; the
state is reachable only by calling `eraGetLeapSeconds` / `eraSetLeapSeconds` /
`eraDatini`; and `eraGetLeapSeconds` has a side effect (it initialises lazily
through `eraDat`) and can return `-1`. No native byte is changed and no
sentinel is invented.

**Targets bound.** Every target, for the first two facts; the third fact is
upstream's and unconditional. The one target-dependent question is *which
branch* `ERFA_THREAD_LOCAL` resolves to (`src/erfadatextra.h:38-50`), and it is
still open exactly where it was: `wasm32-wasi` builds and has never run, so the
chosen spelling was accepted and nothing more. Generalises as: *before
documenting how a caller reaches a library's global state, check whether it is
exported at all — `static` plus a TLS specifier means it is not, the accessor
functions are the whole interface, and their answers may be per-thread.*

## Open questions, and what each one has settled

These are **not** limitations. Each says how far a receipt reaches and where it
stops; a question whose header or compile half is now settled says so in place
and names the run that settled it.

1. Which branch of the `ERFA_THREAD_LOCAL` chain `wasm32-wasi` actually takes
   (`src/erfadatextra.h:38-50`). The 53-platform run records that target as
   `build: pass` / `run: unavailable` — so the chosen spelling was *accepted*,
   and nothing more. A compile does not say which of the five branches was
   selected, and the empty-definition branch compiles and runs without a
   diagnostic, in which case the leap-second state silently becomes
   process-global on that target. Still open; no runtime executed it.
2. Does the libc-less `aarch64-macos-none` target supply `math.h`, `string.h`,
   `stdlib.h` and `float.h`? The core needs all four (`src/erfa.h:15`;
   `src/d2dtf.c`, `src/dtf2d.c`; `src/af2a.c`, `src/moon98.c`, `src/tf2a.c`,
   `src/tf2d.c`; `src/jd2cal.c`), and the upstream validation programs
   additionally need `<stdio.h>` (`src/t_erfa_c.c:3`,
   `src/t_erfa_c_extra.c:9`), so the oracle job is in scope too.
   **Answered, as far as a compile can answer it.** The six-target `check`
   (`zig build check -j2 --summary all`,
   `local://foundation-matrix-erfa-six-baseline.log`) compiles
   `aarch64-macos-none` through the library, the tests, the facade exercise,
   the smoke example and **both** upstream validation programs —
   `Build Summary: 55/55 steps succeeded`. The 53-platform table still contains
   `aarch64-macos`, which is **not** `aarch64-macos-none`; the libc-less target
   appears nowhere in it, and it is the six-target `check`, not that table,
   that now carries this answer. What is settled is the header question.
   Nothing has *run* there, so no runtime claim is made and none is implied.
3. Is `eraDatini` reachable through the raw route safe to expose at all? Upstream
   marks it internal to `dat.c` in two places
   (`src/erfadatextra.h:20-21`, `src/erfadatextra.c:15-16`) and gives it a
   public declaration, and it has **no test anywhere upstream** — measured: it
   is the only one of the 255 declarations with neither a `t_*` validator in
   `src/t_erfa_c.c` nor coverage from `src/t_erfa_c_extra.c`.

4. **Does the entry-18 defect appear outside `Debug`?** Partly answered, and
   the honest residual is narrow. `ReleaseSafe`, `ReleaseFast` and `ReleaseSmall`
   each run all 51 tests green with `.use_llvm` set, so the flag is green in
   every mode this package supports. What is *not* established is whether the
   default backend is wrong in those modes too — no run without `-fllvm`
   exists outside `-ODebug`, because there is no reason to build a package that
   publishes a mandatory flag in a configuration it tells consumers not to use.
   This package sets the flag unconditionally because a mode-dependent
   workaround nobody has measured is a worse contract than one unconditional
   flag.
5. Are the other wide C signatures affected? `eraApio13` passes the same twelve
   doubles with one pointer (`src/erfa.h:95-98`), `eraAtio13` and `eraAtciq`
   pass more arguments again, and the probe established the boundary only for
   `eraApco13` and `eraUtctai`. The per-declaration answer requires a gate per
   signature, and no such sweep has been run; the package-wide `.use_llvm` is
   what makes the question moot in-tree.
6. **How far the entry-18 fix reaches is a different question from whether the
   package builds.** The 53-platform run (§9a of `README.zig.md`) built and ran
   the suite on **20** targets at 51 passing tests each, every one of those
   builds carrying `.use_llvm`. That is not the same as "20 targets have no
   entry-18 defect": it is "20 targets compiled the whole public surface, ran
   every test green, and one of those tests asserts the `eraApco13` rejection
   that the default backend gets wrong". Targets that only compiled settle
   nothing about runtime behaviour, and the corrected run makes that set
   **33**, not 24 — the nine NetBSD targets joined it when their translation
   route was fixed, which is a compile-time change and no more than that.
7. **Does the NetBSD route work at *run* time?** Answered as far as any gate in
   this package goes: it compiles, on `aarch64-netbsd` directly (`11/11 steps`)
   and on all nine NetBSD rows of the corrected 53-platform run. It has never
   been **executed** on any NetBSD target, and nothing in this package says
   otherwise. "Translates" and "runs" are kept apart here on purpose.

8. **What the packaged bytes are, and whether a consumer builds from them, is
   not a question this repository answers.** The filtered-fetch consumer package
   is driven and recorded outside this tree, in
   `local://foundation-matrix-final-package-proof.json`, and its observed
   receipt is the only evidence that would settle it. Nothing here claims a
   `.erfa` or `.erfa_consumer` fingerprint, a packaged file set or a downstream
   build — in either direction. **The single place this boundary is stated is
   `README.zig.md` §9b**; this file points at it rather than restating a
   state, so the SDK's own documentation can stand on its own without
   anticipating an outcome recorded elsewhere.

## 23. A self cross product is zero in reals and near zero in floating point, and the difference is the compiler's, not the library's

**Condition.** A vector library whose cross product is written as a difference
of two products — here `axb[0] = ya*zb - za*yb` (`src/pxp.c:43-45`) — and a
caller that checks a self cross product for exact equality.

**Symptom.** `eraPvxpv(a, a)` is algebraically the zero vector in both members,
and asserting `== 0.0` on either fails intermittently: the compiled library
returns residuals of order one ulp of the operands, `1e-17` to `1e-16` for
operands of order one. The facade exercise was red on exactly this assertion —
`erfa.vectors.pvxpv(probe_pv, probe_pv).velocity[0] == 0.0`, in
`local://foundation-contract-erfa-full-exercise-real-vector-component-and-angle-contract-repair.log`
— while `60/60 tests` passed and smoke was green.

**Cause.** For identical operands the two products round identically, so
`x - x` is exactly `+0.0` under IEEE-754. That exactness disappears if the
compiler contracts the multiply-add into an FMA: the expression becomes
`fma(ya, zb, -(za*yb))`, in which the first product is *not* rounded before the
subtraction, so the component is the rounding error of one product rather than
zero. The velocity member has the same property, being
`a_p × a_v + a_v × a_p` (`src/pvxpv.c:46-50`) — two cross products computed
separately and then added (`src/ppp.c`). Nothing upstream does is wrong, and no
upstream byte can be changed to prevent it: the contraction is the C compiler's
choice, made on native source this package does not own.

**Fix, in this package's own code.** The self-cross member is checked to an
absolute tolerance of `1e-14` (`zig/api_exercise.zig:751-753`), and exact
equality is used only where upstream's expression contains no product to round:
`eraPmp` and `eraPpp` are componentwise `-` and `+` (`src/pmp.c`, `src/ppp.c`),
so `pvmpv(a, a).position[i]` is exactly `0.0` and `pvppv(a, a).position[i]` is
exactly `2a`, and both are asserted exactly (`zig/api_exercise.zig:749-750`).
No assertion anywhere claims bitwise equality for a product-bearing identity.

**Targets bound.** Every target, and every compiler that may or may not
contract. The generalisation: *an algebraic identity over floating-point operands
is not a bitwise identity. Decide per expression whether it contains a
multiplication, and assert exact equality only where it does not.*

## 24. "Update a pv-vector" copies the velocity and rounds the product, and two routines that sound alike need not agree

**Condition.** Two upstream routines that answer "the position after `dt`" — one
returning a full pv, one returning only the position — and a caller that
expects them to agree bit for bit, or that expects the velocity to have been
scaled by `dt`.

**Symptom.** `eraPvu(dt, pv, upv)` is `eraPpsp(pv[0], dt, pv[1], upv[0])`
followed by `eraCp(pv[1], upv[1])` (`src/pvu.c:37-38`). Two consequences a
caller gets wrong: the velocity member is a **verbatim copy** and is not
multiplied by `dt`; and the product `dt·v` is computed by `eraSxp` into a
temporary and only then added (`src/ppsp.c`), so it is rounded separately.
`eraPvup` instead writes `p[i] = pv[0][i] + dt * pv[1][i]` in a single
expression (`src/pvup.c:37-39`), which a compiler may contract into one fused
multiply-add. The two can therefore differ in the last bit while both are
correct.

**Cause.** Two different expression trees for the same mathematical quantity,
over operands that are not closed under rounding. Upstream's own documentation
is about the mathematics, not the bit pattern: the note is "the time units of
`dt` must match those of the velocity" (`src/pvu.c:23`), and upstream asserts no
relation between the two routines.

**Fix, in this package's own code.** `pvu`'s position is checked against
`p + 0.5·v` at `1e-14` rather than by equality, `pvup` is checked only for
finiteness (`zig/api_exercise.zig:740-743`), and neither wrapper promises
anything about the other's bits. No "consistency" assertion is written, because
no such property exists to assert.

**Targets bound.** Every target. Generalises as: *when two routines compute the
same quantity by different expressions, the quantity is the contract and the
bits are not.*

## 25. Position angle and angular separation share a signature and answer different questions

**Condition.** A family of four routines — `eraPap`, `eraPas`, `eraSepp`,
`eraSeps` — all of which take two directions and return an angle, and a caller
or a test that checks the wrong pair against each other.

**Symptom.** A check of the form "the vector form agrees with the
longitude/latitude form" is correct only when both sides are the same quantity.
`eraPap` returns the **bearing** of `b` as seen from `a`, in `[-pi, pi]`, north
zero and east positive (`src/pap.c:20-24`, computed as `atan2(st, ct)` at
`src/pap.c:84`, with `st` the component along the local east axis), and returns
zero for coincident directions or a null operand (`src/pap.c:28-29,56-59,80`).
`eraSepp` returns the **separation** of the two directions, in `[0, pi]`, as
`atan2(|a×b|, a·b)` (`src/sepp.c:44-46`), and returns zero only when both the
sine and the cosine parts are zero. For two points a degree apart the bearing
can be near zero while the separation is near one degree, and both answers are
correct.

**Cause.** Upstream's naming convention — `pap`/`pas` for *position angle*,
`sepp`/`seps` for *separation* — is legible only to a caller who already knows
which question is being asked, and the four declarations sit together in one
`erfa.h` section.

**Fix, in this package's own code.** Each routine is checked against its own
partner and never against the other family: `pap(p, q) == pas(...)` and
`sepp(p, q) == seps(...)`, both at `1e-12` (`zig/api_exercise.zig:756-765`).
Each wrapper's doc comment states which quantity it returns and its range. The
one upstream degeneracy this package does **not** paper over is that `eraPap` is
ill-defined when `a` is at a pole (`src/pap.c:31`): that is stated, not
substituted for.

**Targets bound.** All; it is a semantics question, not a numerical one.
Generalises as: *two same-arity functions in one section are not
interchangeable, and the check that catches this is pairwise agreement between
each function and its own alternative spelling — never agreement across
families.*

## 26. An in-place matrix rotation leaves one row alone, so the identity seed is the precondition

**Condition.** A C library whose rotation routines take an `r-matrix` as *given
and returned* — here `eraRx`, `eraRy`, `eraRz` — and a wrapper that wants to
expose them as constructors.

**Symptom.** Calling `eraRx(phi, r)` on an uninitialised matrix returns a matrix
whose first row is whatever was in that memory, and the result is neither a
rotation nor anything else meaningful. The failure is silent: no status, no
sentinel, and the matrix still passes a casual "is it a matrix" glance. It
surfaced as a failing test — `matrices: a rotation is undone by its transpose`,
`actual 0.7648421872844885, not within absolute tolerance 1e-15 of expected 1`,
in `local://foundation-contract-erfa-linked-native-identity-precondition-fixed-full-api-test.log`.

**Cause.** Each routine mixes two of the three rows and writes them back, leaving
the third exactly as it found it: `eraRx` mixes rows 1 and 2 (`src/rx.c:43-55`),
`eraRy` rows 0 and 2 (`src/ry.c:43-55`), `eraRz` rows 0 and 1
(`src/rz.c:43-55`). Upstream's own note says "Given and returned"
(`src/rx.c:14-15`), which is a precondition, not an initialisation.

**Fix, in this package's own code.** The three constructors seed the identity
first — `var matrix = identity(); c.eraRx(phi, &matrix);`
(`zig/root.zig:3256-3272`) — and `eraIr` writes all nine entries rather than
only the diagonal (`src/ir.c:20-28`), so the seed is complete rather than
partial. `eraRv2m` has the complementary property and is documented rather than
guarded: a zero rotation vector returns the identity because `phi = 0` leaves
`s = 0` and `f = 0` (`src/rv2m.c:42-60`, upstream's note 2 at
`src/rv2m.c:23-24`).

**Targets bound.** All. Generalises as: *a C routine that takes a structure as
"given and returned" imposes a precondition on every member it does not write.
If a wrapper presents it as a constructor, the wrapper — not the C — owes the
caller a fully initialised argument.*

## 27. A routine that returns no status may still clamp, and its second answer may be negative

**Condition.** A numerical model that returns `void`, applies its own bounds
internally, and whose second output carries a sign that surprises a reader.

**Symptom.** Two failures with the same shape. First: reading `eraRefco`'s two
constants as "two positive coefficients". `*refa = gamma * (1 - beta)` is
positive and `*refb = -gamma * (beta - gamma / 2)` is **negative** for every
ordinary observing temperature, because `beta = 4.4474e-6 * tk`
(`src/refco.c:198`) is around `1.26e-3` while `gamma` is around `2.8e-4`
(`src/refco.c:202-203`). Upstream's own oracle agrees:
`vvd(refb, -0.2598658261729343970e-6, 1e-18, ...)` at `src/t_erfa_c.c:8006`.
Second: expecting an out-of-range argument to be refused. It is not — upstream
clamps silently with `ERFA_GMAX`/`ERFA_GMIN`, temperature to `[-150, 200]`,
pressure to `[0, 10000]`, humidity to `[0, 1]` and wavelength to `[0.1, 1e6]`
(`src/refco.c:167-174`, `erfam.h:106-109`), and returns no diagnostic.

**Cause.** Both are properties of the model rather than of the API's shape. A
refraction polynomial's cubic coefficient is legitimately negative; a
performance-oriented atmospheric model clamps rather than branches. Neither is
visible from the C signature, which is
`void eraRefco(double, double, double, double, double*, double*)`.

**Fix, in this package's own code.** The wrapper returns a `RefractionConstants`
record with no `Status`, because there is none to carry, and **no range check is
invented**: an out-of-range argument yields the answer for the clamped value,
exactly as upstream does. The sign is carried as computed — neither flipped nor
made absolute — and the exercise asserts only what the source guarantees,
`refa > 0.0 and refb < 0.0` at `1010 hPa, 10 °C, rh 0.5, 0.55 µm`
(`zig/api_exercise.zig:679-688`). `README.md` §4.6 and `README.zig.md` §3d state
both facts where a caller meets them.

**Targets bound.** All; both are semantic. Generalises as: *`void` means there
is no status to fabricate — and it does not mean there is no validation, because
a routine can bound its inputs silently. Read the body before assuming either.*

## 28. A development task runs in the caller's directory, and this SDK's directory is not the caller's

**Condition.** A canonical environment invoked the way this workspace invokes
one — `devenv --from path:<sdk> tasks run --mode single <name>`, with the *working
tree* supplied by `--from` and a separate, disposable project directory as the
caller's cwd — and task bodies written as bare `zig build …` or
`sha256sum -c UPSTREAM.sha256`.

**Symptom.** Two gates, both reported against correct code. `sdk:consumer`:
`info: initialize build.zig template file with 'zig init'` then `error: no
build.zig file found, in the current directory or any parent directories`.
`sdk:licence`: `sha256sum: UPSTREAM.sha256: No such file or directory`
(driver run `20261004T175328Z`, evidence
`…/contract-physics-lua/nix-acceptance-evidence/20261004T175328Z/`). The task
program is materialised into `/nix/store/…-<task>` and started in the caller's
directory; `devenv info` prints the same directory as `DEVENV_ROOT`, and that
directory has no `build.zig`, no `UPSTREAM.sha256` and no `consumer/`. The
tempting repair — `cd "$DEVENV_ROOT"` — writes the bug into nine tasks at once,
because `DEVENV_ROOT` names the scratch project, not this checkout.

**Fix.** One binding in `devenv.nix`, `sdkRoot = builtins.toString ./.;`, and a
`cd ${lib.escapeShellArg sdkRoot}` as the first line of every `exec`. Two details
are load-bearing. `./.` is resolved **relative to the file that writes it**, so
the root is this SDK's own directory whether the caller was in a scratch project,
the checkout, or anywhere else; and `builtins.toString` is used rather than an
interpolated `${./.}`, because the interpolated form can pull the whole tree into
the read-only Nix store, and a store copy is not a directory `zig build` may
write a cache into. `sha256sum -c` is the one command that cannot be repaired by
naming its record absolutely: it resolves every path in `UPSTREAM.sha256`
against the working directory, so the change of directory is the fix, not a
convenience.

**Targets bound.** None — this is packaging, and no `.c`, `.h`, Zig surface,
count or digest record is involved. Two related rules were learned with it, both
about where a task writes rather than what it reads. `zig build`'s default prefix
is `zig-out/` **inside the checkout**, and this tree's default step *is* an
installing one — `build.zig:1473` installs the artefact and `:1489-1490` hang the
smoke and exercise compilations off the install step — so `sdk:build` resolves
`--prefix` from **exported** values only: `$ERFA_INSTALL_PREFIX`, then
`$ZIG_LOCAL_CACHE_DIR/erfa/build`, then `$TMPDIR/erfa/build`; and
`sdk:shared-install` resolves its own the same way — `$ERFA_INSTALL`, then
`$ZIG_LOCAL_CACHE_DIR/erfa/shared`, then `$TMPDIR/erfa/shared` — and passes `-j8`
with its existing `-Dlinkage=dynamic`. With none of the three exported there is
no prefix: the task names what to export on stderr and stops. `/tmp` is not a
default this file may supply, and a host path is not either — a location is the
caller's to export, and an invented one is how a checkout ends up holding delivery
output. No branch of either chain is inside the checkout, neither task sets nor
unsets anything, and the five tasks that do not depend on the install step —
`test`, `smoke`, `consumer`, `upstream-test`, `check` — are given no prefix at all.
Generalises as: *an entry point that documents itself by a path relative to
itself must open by making that path explicit; a task's working directory is
the caller's, never the module's, and `$DEVENV_ROOT` is not the module.*

## 29. A doc comment can contradict the header it sits on, and a run step can document a flag it never forwards

**Condition.** Three independent ways a published contract stops describing the
code, all found by reading this tree against `src/` rather than by running it:
a typed record whose field docs restate an upstream `int` with the wrong shape;
a provider-ABI document that promises what the build configuration explicitly
declines to decide; and a `Step.Run` whose program documents a command-line
flag the step never forwards.

**Symptom.** Each looks like a typo and behaves like a defect.
`TporsResult.status` read as a signed quality ladder ("`2` … comfortably
inside", "the `+1` solution", "the `-1` solution") while its own header comment
and `README.zig.md` §3a said the integer was a count: a caller filtering on
`status.isWarning()` drops the *usual* case, because `1` — one useful solution,
the normal answer — is positive. `runtime/library.zig` said the leap-second
state "lives in thread-local storage" and that "this package's build is the
reason that last branch is not taken", while `build.zig:158-194` states the
opposite on purpose: no `-std=`, no `ERFA_THREAD_LOCAL`, and a target on the
empty arm "would compile and run without a diagnostic". And `consumer`'s program
documents `--provider <path>` on its command line while neither
`consumer/build.zig` nor `build.zig`'s own `consumer` step passed `b.args`, so
the flag reached the program as nothing and it exited telling the caller to pass
the flag they had just passed. The same class reached the module documentation
twice over: `zig/root.zig` and `README.zig.md` §1b both showed
`/usr/lib/liberfa.so.2`, while `README.md` §4.5 and `build.zig`'s own
`abi_version` said the soname is `liberfa.so.1`.

**Fix, in documentation and build configuration only.** Quote the upstream
ladder where the record declares it, with the branch that decides it
(`(fabs(rsb) < 1.0) ? 1 : 2`), and name the outputs `Soln. 1`/`Soln. 2`; state
that a count of `1` means the second is not *useful* rather than absent, since
upstream writes both on the same path. For the provider ABI, state the branch as
compiler-dialect-dependent, keep only the compatibility rule that survives
either branch (a process-global provider is a different thread-safety contract
and not an interchangeable provider), and say that `validate` cannot tell the
two apart. For the run step, forward `b.args` wherever a program parses its own
arguments. No native byte, signature, option, default or install layout changed.

**Targets bound.** The ladder and the soname are per-pins and must be re-read on
every re-pin; both are `SOURCE-CONFIRMED` from `src/tpors.c`, `src/tporv.c` and
`configure.ac:20`. The thread-local branch is the same open question entry 22
and the open-questions list already carry, and it is unchanged by this entry —
what changed is that no file now claims to have settled it. The argument
forwarding is per-package and version-free: any `Step.Run` whose program reads
`init.minimal.args` needs `b.args`, whether or not the run cache would have
hidden it.

## 30. A CI step that installs must name a prefix, and everything that reads the install must follow it

**Condition.** A `zig build` with no step named, which is an **installing**
invocation — this graph's default step installs the artefact, the four headers,
the pkg-config file and the licence records (`build.zig:1473-1484`) — written
into a workflow that otherwise never writes to the checkout.

**Symptom.** Three steps of `verify.yml` ran a bare `zig build` and wrote
`zig-out/` into the source tree on the runner, while the five steps that read
that tree back named the literal `zig-out/`. The shape was already established
elsewhere in the same repository — `box2d/.github/workflows/verify.yml` passes
`--prefix "$RUNNER_TEMP/shared"` for its shared build — and inside this file the
other build step already routed the installed C program's scratch files to
`$RUNNER_TEMP`. An install tree inside a checkout is also what a later
`zig-out/` in a diff, or a stale one between two steps of the same job, gets
attributed to the wrong step.

**Fix.** Name `--prefix` on every step whose step list includes the install
step, under the runner's own `$RUNNER_TEMP`; here `erfa-default`, `erfa-static`
and `erfa-shared` for the three jobs. Every check that reads the installed tree
follows the same prefix through one local `dest=` binding. Steps whose step list
is `test`, `upstream-test`, `smoke`, `check` or `consumer`'s `run` reach no
install step and are given no prefix, so the flag marks exactly the steps that
need it. No job, target, flag or step was added, removed or reordered.

**Targets bound.** None — this is workflow convention, and it generalises past
Zig: *in CI, "the default step" installs in every build system that has a
default install target, so an unqualified build command is a write into the
checkout; redirect the prefix and move every consumer of that prefix with it.*
