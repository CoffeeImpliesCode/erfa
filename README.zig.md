# README.zig.md — the Zig 0.16 package for ERFA

ERFA is the IAU's *Essential Routines for Fundamental Astronomy*: C routines for
astronomical timescales (TAI, TT, TCG, TCB, TDB, UT1, UTC), leap seconds,
precession/nutation and frame rotations, ICRS-to-observed transformations,
analytical Earth/Moon/planet ephemerides, and the small vector, matrix and
spherical-coordinate algebra those need.

This package exposes that library to Zig in two ways, and the split is
deliberate:

- a **complete raw C route** — every one of the 255 functions and 35 macros
  upstream declares, reached through the translated headers, for the code that
  wants the upstream API exactly as SOFA/ERFA documents it;
- a **bounded typed route** — a small, explicitly enumerated set of routines
  with Zig types, for the code that wants two-part dates, timescales and status
  values it does not have to re-derive at every call site.

Nothing here reimplements a SOFA algorithm, and no upstream byte is modified.
Every *measurement* in this document was read out of the tree.

Status vocabulary is `foundation-libs/AGENTS.md` §2. Most of this document is
`SOURCE-CONFIRMED`. The driver has run a set of gates, and each one is recorded
where it belongs — §1a for the backend requirement, §4 for the translation
route, §9 for the full list — naming its receipt, and claiming nothing beyond
what that receipt carries.

**Two tables of gates, because the tree changed underneath the older one.** On
2026-10-03, before this package's contract migration, the native run passed in
**all four modes** — `Debug`, `ReleaseSafe`, `ReleaseFast` and `ReleaseSmall` —
each at **51/51 tests**; the six-target `check` compiled all six required
targets (`55/55 steps`); an `aarch64-netbsd` `check` translated (`11/11
steps`); a two-run discriminator showed the default backend returning a wrong
`eraApco13` status; a current-install C program compiled, linked and ran; and
the 53-platform matrix ran with **20 runtime passes at 51 tests each, 33
`build_only` and 0 failures**. Those receipts are in §9a and they describe that
tree.

**Against the tree as it now stands**, the typed route is 197 members across 18
namespaces (§3) rather than 99 across 8, `tests.zig` is 61 tests rather than 51,
and the current evidence is §9a.2: the full SDK suite plus the facade exercise
plus the smoke example pass in one `Debug` linked run at `12/12 steps` and
`60/60 tests`, a second consumer program passes, the two upstream validation
programs print `validation successful`, `-Dlinkage=dynamic` installs a shared
object whose only defined symbols are the 255 `era*` entry points, a
runtime-loaded smoke against an explicitly named provider passes, and every one
of the 268 recorded upstream files still matches its digest. **The
runtime-loaded `ReleaseSafe` run is red.** It passes the same 60 tests and the
smoke example and then aborts in the facade exercise at `vectors.s2xpv`, where
the wrapper was passing a three-double object for an out-parameter upstream
fills with six; §3e records the correction and names the receipt. That
correction landed after every row in §9a.2 was taken. **§9a.3 is the current
evidence and supersedes that paragraph**: the corrected surface now runs its own
full suite green in **all four** optimize modes crossed with both linkages
(`25/25 steps succeeded; 61/61 tests passed` linked, `26/26 steps; 61/61 tests`
loaded, in all eight native cells each), it **does** have a 53-platform matrix
(`20 pass, 0 fail, 33 build_only`, exit 0, 61 tests on every executed cell), and
it **does** have an integrated runtime gate across the four runtime/linkage
combinations, against this tree's own `liberfa.so.1.8.1` named by absolute path.
What remains pending is named per row there: the `consumer` and `upstream-test`
steps under `-Druntime=true`, the consumer-behaviour `load` checks, the Windows
`DEF` export list, both Nix derivations, the devenv routes, and the installed-C
consumer linked and run against `lib/liberfa.so`. Thirty-three `build_only` cells
are not passes, and the six-target `check` baseline is compile-only.

**Two boundaries.** The filtered-fetch consumer package is driven and recorded
outside this repository, in
`local://foundation-matrix-final-package-proof.json`; §9b says what that record
does and does not license either of us to claim, and nothing here asserts an
outcome for it. And the driver has not executed
`.github/workflows/verify.yml` — every receipt named in this document is a
direct `zig` or `sha256sum` invocation, not a CI result. The one place workflow
material is reused is the installed-C program, which is the workflow's own C
source run by the driver against the current install; §9c states that
precisely. Everything not covered by a named receipt is `SOURCE-CONFIRMED` (read
out of a file) or `PENDING-VERIFICATION` (landed, no gate has looked at it
yet).

---

## 1. Names and entry points

| Thing | Name |
|---|---|
| Zig package | `erfa` (declared in `build.zig.zon`) |
| Build module and static artifact | `erfa` |
| Consumer package | `consumer`, depending on the package by relative path |
| Raw C route | `erfa.c` — the translated headers, published from the same module. Upstream's own documentation is the contract and it ships in the installed headers; the raw route's doc comments point at those files rather than paraphrasing them. |

Consumers use the published module only. There is no second, redundant
artifact link to add.

`zig/root.zig` is the single place where the Zig identifier names live. §2 names
upstream's C identifiers, which are fixed by the headers and cannot drift; §3
names the Zig ones and is explicitly subordinate to `zig/root.zig`.

### 1a. The compilation backend is part of the consumer contract

**Consumers must build with LLVM.** `.use_llvm = true` on every Zig executable
root that reaches this package's `erfa` module, or `-fllvm` on the command
line. This is not a preference and not a workaround for a source defect: it is
what makes `eraApco13`'s status correct.

**The finding, as observed.** On 2026-10-03 the driver built one probe program
twice against **one** archive, changing nothing but the backend flag. The two
runs are receipts `local://foundation-matrix-erfa-boundary-isolation.log`
(default native backend, exit 0) and
`local://foundation-matrix-erfa-boundary-llvm-discriminator.log` (identical
argv with a leading `-fllvm`, exit 0). Both link the same
`…/erfa/local/o/3fc96734ab923532bbeb6b9530bfc70e/liberfa.a`, the same
`zig/root.zig` and the same `translate.zig`, at `-ODebug`, native target,
Zig 0.16.0. The probe calls `eraApco13` twice — once through the raw route and
once through `erfa.rotation.apco13` — and `eraUtctai`, on a valid 2013 date
`2456384.5 + 0.969254051` and on an unacceptable `−1e10 + 0`:

| Probe date | What it is | Native backend | `-fllvm` |
|---|---|---|---|
| `2456384.5 + 0.969254051` | valid | raw `1`, typed `1` — **wrong** | raw `0`, typed `0` — correct |
| `−1e10 + 0` | unacceptable | raw `1`, typed `1` — **wrong** | raw `−1`, typed `−1` — correct |
| both | `eraUtctai` status | `0` / `−1` | `0` / `−1` — unchanged |

Read that as separate facts, and keep each one at the width the receipt
supports:

- **The C is not what changed, and neither is the facade's own logic.** The raw
  route (`erfa.c.eraApco13`) and the typed route (`erfa.rotation.apco13`) read
  the *same* wrong status, the two runs link the *same* `liberfa.a`, and no
  byte of `src/` differs between them. What differs is one flag. Where inside
  the Zig front end that goes wrong — argument marshalling, the call, the
  backend's handling of a wide C signature — is **not established**; this
  package did not bisect it and does not claim a cause.
- **`eraApco13` is a wide signature.** It is a fourteen-argument call: twelve
  `double` scalars and two pointers, `eraASTROM *astrom` and `double *eo`
  (`src/erfa.h:80-83`). `eraApio13` passes the same twelve doubles with one
  pointer (`src/erfa.h:95-98`) and `eraUtctai`, also in the same probe, passes
  two doubles and one pointer (`src/utctai.c`) — and is unaffected, in both
  runs, at both inputs. So this is not "Debug is broken" and not "the whole
  boundary path is broken"; it is bounded to the observed probe.
- **`+1` is not a plausible answer for either input.** `+1` is upstream's
  *dubious year* **warning** (`src/dat.c:69-78,225`), it still computes, and
  2013 is nowhere near the 2029 threshold. Under the native backend the
  unacceptable date `−1e10` also comes back `+1` instead of `−1`. Both values
  are what a caller reading a wrong status would treat as "worked, with a
  caveat".

**Scope, stated so it is not over-read.** The discriminator itself is observed
on this host, this compiler, `-ODebug`, native target, for these two inputs
through these two routes. It is **not** evidence about the other 254
declarations. The later gates bound the fix rather than bisect its cause:
`ReleaseSafe`, `ReleaseFast` and `ReleaseSmall` each run all 51 tests green
with `.use_llvm` set (§9a), and one of those 51 is the `eraApco13` rejection
this defect breaks, and the 53-platform run executes all 51 on 20 further
targets with the same flag. That is why the flag is unconditional in this
package rather than mode-dependent — it is a bound on the fix, not a
bisection of the cause. The six-target `check` is `OBSERVED` (`55/55 steps`)
but runs nothing, so it contributes compile-time, not behavioural, evidence.

**What this package does about it.** Two build-only changes, no native source
edit and no shim:

- `build.zig` sets `.use_llvm = true` on the `addTest` root and each Zig
  executable root that imports the facade: the exercise, smoke and consumer.
  The two C-only upstream validation programs do not need this Zig-root flag.
- `consumer/build.zig` sets `.use_llvm = true` on its own executable root.

**The requirement is on Zig roots only.** Every **Zig** executable or test root
that imports this package's `erfa` module — this package's own exercise, smoke
and consumer, `tests.zig`, and any external consumer's root — must set
`.use_llvm = true`. A pure C program linking `liberfa.a` has no Zig root and
needs no flag: the installed-C program in §9a is compiled by `zig cc` with no
backend flag at all and runs correctly. The flag buys a correct status on a
Zig call across the C ABI, and only a Zig call can need it.

**What a module cannot do, and the rule that follows.** A published Zig module
cannot force a dependent's backend: the choice belongs to the
`addExecutable`/`addTest` root the dependent owns, and this package has no
authority over an external consumer's `build.zig`. So the requirement is
documented and demonstrated rather than enforced from inside, and **every
external consumer must state it itself**:

```zig
const dep = b.dependency("erfa", .{ .target = target, .optimize = optimize });
const mod = b.createModule(.{
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
});
mod.addImport("erfa", dep.module("erfa"));   // the module is the whole of it
const exe = b.addExecutable(.{
    .use_llvm = true,                          // REQUIRED; see 1a
    .name = "my-erfa-consumer",
    .root_module = mod,
});
```

For a hand-written command line, `-fllvm` is the equivalent. This is the shape
the two discriminator receipts used, with the absolute paths elided:

```sh
zig run -ODebug --dep erfa \
  -Mroot=…/erfa-boundary-probe.zig \
  …/erfa/local/o/3fc96734ab923532bbeb6b9530bfc70e/liberfa.a \
  -ODebug --dep c \
  -Merfa=…/foundation-libs/erfa/zig/root.zig \
  -Mc=…/erfa/local/o/597f3ec1c5e122103ae5bbb38a133f5a/translate.zig \
  -lc -lm
```

There is deliberately **no** alternative: no patched `src/apco13.c`, no
`#define` shim, no hand-written wrapper that reorders arguments, no detection
that silently reports a different value. The native bytes are covered by
`UPSTREAM.sha256` and the backend is the build's business.

**The cost is real and is not hidden.** `.use_llvm` selects a different
code generator and a larger toolchain footprint than the default backend.
That is the price of a correct `eraApco13` status; it is not an ERFA cost and
not a claim that LLVM is faster or safer here.

### 1b. Two configurations, and the runtime one is opt-in

`runtime_loaded` is a **comptime** constant, so a consumer can write two code
paths and have only the one it chose analysed. False (the default) is a linked
build: `c` is the translated header itself, every call is direct, and there is
no table and no readiness check. True under `-Druntime=true` is the
runtime-loaded build described in `README.md` §4.5.

```zig
const erfa = @import("erfa");

pub fn main() !void {
    if (comptime erfa.runtime_loaded) {
        try erfa.load(.{ .path = "/usr/lib/liberfa.so.1" });
    }
    // ordinary module calls from here
}
```

`liberfa.so.1` is the soname, not a guess: `configure.ac:20` records
`ERFA_LIB_VERSION_INFO(9, 1, 8)`, libtool's `(C - A).A.R` gives `9 - 8 = 1` for
the soname number, and `build.zig`'s `abi_version` carries the same `1.8.1`
that `meson.build` derives. `.path` names a file, so the versioned file name
`liberfa.so.1.8.1` names it too; any other spelling is a file the loader will
not find.

The exported surface under `-Druntime` is `LoadSource`, `LoadError`,
`load(source)` and `loadedSource()`. `LoadSource` is `.path` or `.system` and
neither falls back to the other; the handle and the module's copy of the request
live to the end of the process. Nothing here has been observed running; see
`README.md` §3.3.

## 2. The raw C surface, in full

This section is complete, because "complete" here is measurable: it is
everything the four installed headers declare.

### 2a. Shape

| Header | Bytes | Function declarations | Macros | Public struct types |
|---|---:|---:|---:|---|
| `erfa.h` | 27,288 | 247 | 0 | `eraASTROM` (17 fields), `eraLDBODY` (3 fields) |
| `erfam.h` | 5,873 | 0 | 35 | — |
| `erfaextra.h` | 1,690 | 7 | 0 | `eraLEAPSECOND` (2 fields) |
| `erfadatextra.h` | 1,488 | 1 | 0 | — |
| **Total** | **36,339** | **255** | **35** | **3** |

`erfa.h` includes `math.h` (`src/erfa.h:15`) and nothing else from ERFA.
**It does not include `erfam.h`** — upstream made that explicit for 2.0.0
(`README.rst:66-68`) — so a caller that wants the constants must include
`erfam.h` too. All four headers carry `extern "C"` guards. Any translated
header pair must reproduce both files; 107 of the 249 core `.c` files include
`"erfam.h"` themselves and 142 do not.

### 2b. Every `erfa.h` group, with its declaration and status counts

Counts are mechanical, from the section comments upstream itself wrote into
`erfa.h`; the "status" column is the number of those declarations that return a
signed SOFA-style status (§2c).

| Group (`erfa.h` line) | Declarations | Return status |
|---|---:|---:|
| Astronomy/Calendars (50) | 7 | 3 |
| Astronomy/Astrometry (60) | 35 | 7 |
| Astronomy/Ephemerides (172) | 3 | 2 |
| Astronomy/FundamentalArgs (178) | 14 | 0 |
| Astronomy/PrecNutPolar (194) | 64 | 0 |
| Astronomy/RotationAndTime (303) | 15 | 0 |
| Astronomy/SpaceMotion (321) | 2 | 2 |
| Astronomy/StarCatalogs (328) | 10 | 1 |
| Astronomy/EclipticCoordinates (365) | 6 | 0 |
| Astronomy/GalacticCoordinates (375) | 2 | 0 |
| Astronomy/GeodeticGeocentric (379) | 5 | 5 |
| Astronomy/Timescales (390) | 20 | 19 |
| Astronomy/HorizonEquatorial (423) | 3 | 0 |
| Astronomy/Gnomonic (430) | 6 | 4 |
| VectorMatrix/AngleOps (442) | 8 | 3 |
| VectorMatrix/BuildRotations (452) | 3 | 0 |
| VectorMatrix/CopyExtendExtract (457) | 5 | 0 |
| VectorMatrix/Initialization (464) | 4 | 0 |
| VectorMatrix/MatrixOps (470) | 2 | 0 |
| VectorMatrix/MatrixVectorProducts (474) | 4 | 0 |
| VectorMatrix/RotationVectors (480) | 2 | 0 |
| VectorMatrix/SeparationAndAngle (484) | 4 | 0 |
| VectorMatrix/SphericalCartesian (490) | 6 | 0 |
| VectorMatrix/VectorOps (502) | 17 | 0 |
| **Subtotal in `erfa.h`** | **247** | **46** |

Plus, outside `erfa.h`:

| Header | Function | Returns |
|---|---|---|
| `erfaextra.h:34` | `eraVersion` | `const char *` |
| `erfaextra.h:41,48,55` | `eraVersionMajor`, `eraVersionMinor`, `eraVersionMicro` | `int` — a version number, **not** a status |
| `erfaextra.h:62` | `eraSofaVersion` | `const char *` |
| `erfaextra.h:74` | `eraGetLeapSeconds` | `int` — entry count `> 0`, or `-1` on internal error |
| `erfaextra.h:75` | `eraSetLeapSeconds` | `void` |
| `erfadatextra.h:23` | `eraDatini` | `int` — entry count. Upstream marks this internal to `dat.c` (`src/erfadatextra.h:20-21`) |

### 2c. Return-value taxonomy, and the trap inside it

Over all 255 declarations, measured:

| Return | Count | Meaning |
|---|---:|---|
| `void` | 151 | results go to caller-provided pointers |
| `double` | 51 | a scalar result, always paired with out-parameters or a fixed argument |
| `const char *` | 2 | a static version string |
| `int` | **51** | **not one kind of thing** |

The 51 `int` returns split, measured, into:

- **44 signed SOFA-style statuses** — `0` success, **positive = warning**,
  **negative = error**. All 44 are in `erfa.h`; the "status" column of §2b sums
  to 46 and includes the two counted next.
- **2 solution counts, not statuses.** `eraTpors` (`src/tpors.c:23-26`) and
  `eraTporv` (`src/tporv.c:23-26`) return `0`, `1` or `2`, documented as the
  *number of solutions* — none of which is an error code.
- **3 version numbers.** `eraVersionMajor`, `eraVersionMinor`, `eraVersionMicro`.
- **1 entry count with `-1` as its only error.** `eraGetLeapSeconds`
  (`src/erfadatextra.c:33-37`).
- **1 entry count.** `eraDatini` (`src/erfadatextra.c:85-87`).

**Consequence for any wrapper.** Typing every `int` return as a status is wrong
for seven functions. Typing a `> 0` return as "error" is wrong for the warning
half of the other 44. That is why the typed route keeps the signed integer
visible instead of collapsing it to a boolean, and why `eraTpors`/`eraTporv` are
not counted as status-returning in this document.

### 2d. The upstream validation oracle

`src/t_erfa_c.c` defines exactly **247** `static void t_*` validators and its
`main()` calls exactly **247** of them — every one defined, none called twice
(`src/Makefile.am:49-52`, `src/meson.build:48-51` name both programs).
`src/t_erfa_c_extra.c` adds two: `t_versions` and `t_leap_seconds`.

Mapping validator names to declarations, **247 of the 255 declared functions
have a dedicated validator** in `t_erfa_c.c`. The eight that do not are the
seven non-SOFA entry points plus one internal: `eraVersion`,
`eraVersionMajor`, `eraVersionMinor`, `eraVersionMicro`, `eraSofaVersion`,
`eraGetLeapSeconds`, `eraSetLeapSeconds` and `eraDatini`. The first seven are
exercised indirectly by `t_versions` and `t_leap_seconds`;
**`eraDatini` has no test anywhere upstream.**

The expected values in `t_erfa_c.c` are inherited from SOFA's own validation
suite — upstream states that ERFA differs from SOFA only in the `era` prefix,
the `ERFA_` macro prefix, and the added version and leap-second entry points
(`README.rst:19-48,52-59`). They are therefore a **reference oracle**, not a
same-code round trip, and they are the fixture this package's reference-oracle
gate uses. They carry their own BSD-3 footer and ship unmodified.

## 3. The typed route: actual published surface

The typed route is **bounded on purpose**. Measured from `zig/root.zig` as it
stands in this tree: **18 namespaces, 197 members, wrapping 197 distinct C
functions.** Every one of the 197 was checked against the four headers — all
197 are real declarations, and none is invented. The other **58** of the 255
stay reachable through `c`, which is the same module. The typed route is an
addition; it is never a restriction, and it reimplements no SOFA algorithm.

The typed route is final for this wave: no namespace grows after this document.

| Namespace | Members | Wraps |
|---|---:|---|
| `erfa.leap` | 3 | `eraGetLeapSeconds` `eraSetLeapSeconds` `eraDatini` |
| `erfa.calendar` | 13 | `eraCal2jd` `eraJd2cal` `eraJdcalf` `eraDtf2d` `eraD2dtf` `eraD2tf` `eraTf2d` `eraTf2a` `eraAf2a` `eraEpb` `eraEpb2jd` `eraEpj` `eraEpj2jd` |
| `erfa.timescale` | 18 | `eraDat` `eraTaiutc` `eraUtctai` `eraUtcut1` `eraUt1utc` `eraUt1tai` `eraTaiut1` `eraUt1tt` `eraTtut1` `eraTaitt` `eraTttai` `eraTcgtt` `eraTttcg` `eraTcbtdb` `eraTdbtcb` `eraTdbtt` `eraTttdb` `eraDtdb` |
| `erfa.rotation` | 20 | `eraEra00` `eraGmst00` `eraGmst06` `eraGmst82` `eraGst00a` `eraGst00b` `eraGst06a` `eraGst94` `eraGst06` `eraEe00` `eraEe00a` `eraEe00b` `eraEe06a` `eraEect00` `eraApco13` `eraApio13` `eraAtco13` `eraAtio13` `eraAtoc13` `eraAtoi13` |
| `erfa.geodetic` | 5 | `eraEform` `eraGc2gd` `eraGc2gde` `eraGd2gc` `eraGd2gce` |
| `erfa.precession` | 36 | `eraObl06` `eraObl80` `eraEqeq94` `eraEo06a` `eraEors` `eraFw2xy` `eraFw2m` `eraPrec76` `eraNut00a` `eraNut00b` `eraNut06a` `eraNut80` `eraNum00a` `eraNum00b` `eraNum06a` `eraNutm80` `eraPn00` `eraPn06` `eraPn00a` `eraPn00b` `eraPn06a` `eraPnm00a` `eraPnm00b` `eraPnm06a` `eraPnm80` `eraPmat00` `eraPmat06` `eraPmat76` `eraPom00` `eraLtecm` `eraLteqec` `eraLteceq` `eraLtp` `eraLtpb` `eraLtpecl` `eraLtpequ` |
| `erfa.ephemeris` | 3 | `eraEpv00` `eraPlan94` `eraMoon98` |
| `erfa.vectors` | 31 | `eraPn` `eraPm` `eraLd` `eraPdp` `eraPmp` `eraPpp` `eraPpsp` `eraPxp` `eraSxp` `eraSxpv` `eraS2xpv` `eraPvm` `eraPvu` `eraPvup` `eraPvdpv` `eraPvmpv` `eraPvppv` `eraPvxpv` `eraPap` `eraSepp` `eraPas` `eraSeps` `eraLdn` `eraLdsun` `eraAb` `eraPvtob` `eraPvstar` `eraStarpv` `eraStarpm` `eraPmsafe` `eraPmpx` |
| `erfa.matrices` | 20 | `eraRx` `eraRy` `eraRz` `eraIr` `eraZr` `eraZp` `eraZpv` `eraRxr` `eraTr` `eraRxp` `eraRxpv` `eraTrxp` `eraTrxpv` `eraRm2v` `eraRv2m` `eraCp` `eraCr` `eraCpv` `eraP2pv` `eraPv2p` |
| `erfa.angles` | 4 | `eraAnp` `eraAnpm` `eraA2af` `eraA2tf` |
| `erfa.spherical` | 6 | `eraC2s` `eraP2s` `eraPv2s` `eraS2c` `eraS2p` `eraS2pv` |
| `erfa.horizon` | 3 | `eraAe2hd` `eraHd2ae` `eraHd2pa` |
| `erfa.ecliptic` | 3 | `eraEceq06` `eraEcm06` `eraEqec06` |
| `erfa.galactic` | 2 | `eraG2icrs` `eraIcrs2g` |
| `erfa.gnomonic` | 6 | `eraTpors` `eraTporv` `eraTpsts` `eraTpstv` `eraTpxes` `eraTpxev` |
| `erfa.atmosphere` | 1 | `eraRefco` |
| `erfa.starCatalogs` | 9 | `eraFk425` `eraFk45z` `eraFk524` `eraFk54z` `eraFk52h` `eraH2fk5` `eraFk5hip` `eraFk5hz` `eraHfk5z` |
| `erfa.fundamentalArgs` | 14 | `eraFad03` `eraFae03` `eraFaf03` `eraFaju03` `eraFal03` `eraFalp03` `eraFama03` `eraFame03` `eraFane03` `eraFaom03` `eraFapa03` `eraFasa03` `eraFaur03` `eraFave03` |
| **Total** | **197** | 197 distinct C functions |

These namespaces are the fork's grouping, not upstream's: `erfa.rotation` and
`erfa.precession` together straddle the `erfa.h` boundary between
`Astronomy/RotationAndTime` and `Astronomy/PrecNutPolar`, and the eight
vector, matrix, angle, spherical, horizon, ecliptic, galactic and gnomonic
groups are upstream's `VectorMatrix/*` sections plus three
`Astronomy/*Coordinate*` sections renamed by what a caller does with them.

**Coverage against `erfa.h`, measured per upstream section.** 194 of the 247
declarations are typed; the 53 that are not are confined to two sections, and
every other section is complete:

| `erfa.h` section | Declarations | Typed | Not typed |
|---|---:|---:|---|
| `Astronomy/Calendars` | 7 | 7 | — |
| `Astronomy/Astrometry` | 35 | 14 | `eraApcg` `eraApcg13` `eraApci` `eraApci13` `eraApco` `eraApcs` `eraApcs13` `eraAper` `eraAper13` `eraApio` `eraAtcc13` `eraAtccq` `eraAtci13` `eraAtciq` `eraAtciqn` `eraAtciqz` `eraAtic13` `eraAticq` `eraAticqn` `eraAtioq` `eraAtoiq` |
| `Astronomy/Ephemerides` | 3 | 3 | — |
| `Astronomy/FundamentalArgs` | 14 | 14 | — |
| `Astronomy/PrecNutPolar` | 64 | 32 | `eraBi00` `eraBp00` `eraBp06` `eraBpn2xy` `eraC2i00a` `eraC2i00b` `eraC2i06a` `eraC2ibpn` `eraC2ixy` `eraC2ixys` `eraC2t00a` `eraC2t00b` `eraC2t06a` `eraC2tcio` `eraC2teqx` `eraC2tpe` `eraC2txy` `eraNumat` `eraP06e` `eraPb06` `eraPfw06` `eraPr00` `eraS00` `eraS00a` `eraS00b` `eraS06` `eraS06a` `eraSp00` `eraXy06` `eraXys00a` `eraXys00b` `eraXys06a` |
| `Astronomy/RotationAndTime` | 15 | 15 | — |
| `Astronomy/SpaceMotion` | 2 | 2 | — |
| `Astronomy/StarCatalogs` | 10 | 10 | — |
| `Astronomy/EclipticCoordinates` | 6 | 6 | — |
| `Astronomy/GalacticCoordinates` | 2 | 2 | — |
| `Astronomy/GeodeticGeocentric` | 5 | 5 | — |
| `Astronomy/Timescales` | 20 | 20 | — |
| `Astronomy/HorizonEquatorial` | 3 | 3 | — |
| `Astronomy/Gnomonic` | 6 | 6 | — |
| all nine `VectorMatrix/*` sections | 55 | 55 | — |
| **Total in `erfa.h`** | **247** | **194** | **53** |

The two untyped sections are the ones whose untyped members are the
intermediate `eraAp*`/`eraAtci*`/`eraC2i*`/`eraC2t*` stages: upstream composes
them into `eraApco13`, `eraAtciq` and the CIO-based equivalents, and the typed
route exposes the composed entry points rather than every stage between them.
Coverage where it is easiest to get wrong is complete: **all 20
`Astronomy/Timescales` declarations are typed**, including `eraDtdb`, and all
five `Astronomy/GeodeticGeocentric` routines are typed.

Outside `erfa.h`: three of the eight are typed — `eraGetLeapSeconds`,
`eraSetLeapSeconds` (`erfa.leap`) and `eraDatini` (`erfa.leap.datini`). The five
that are not are the version accessors `eraVersion`, `eraVersionMajor`,
`eraVersionMinor`, `eraVersionMicro` and `eraSofaVersion`, which are a
`const char *` pair and three integers whose only meaning is this build's
version; they stay on the raw route.

### 3a. Status

`Status` is a struct whose `value` field is the C `int` itself, with
`ok`, `isOk()`, `isWarning()`, `isError()` and `format()`. **There is no Zig
error set anywhere in the typed layer, by design**: an error set cannot carry
the integer value of a SOFA warning, and that value is the information. Every
result type carries its `status` beside its outputs. There are **34** records
whose name ends in `Result`, of which **29** carry a `status`:
`LeapTableResult`, `DateResult`, `Cal2jdResult`, `Jd2calResult`,
`JdcalfResult`, `Dtf2dResult`, `D2dtfResult`, `Tf2dResult`,
`Tf2aResult`, `Af2aResult`, `DatResult`, `EformResult`,
`Gc2gdResult`, `Gc2gdeResult`, `Gd2gcResult`, `Gd2gceResult`, `Apco13Result`,
`Apio13Result`, `Atco13Result`, `Atio13Result`, `Atoc13Result`, `Atoi13Result`,
`Epv00Result`, `Plan94Result`, `PnResult`, `StarMotionResult`, `PvResult`,
`TporsResult`, `TporvResult` and `TpxeResult` each carry one; `D2tfResult`,
`A2afResult`, `A2tfResult` and `Fk5HipResult` carry none, because the C routine
they wrap returns `void` and `Fk5hip` returns no condition at all. `Geodetic` is
the twenty-ninth record with no status: it is an *input* to `gd2gc` and
`gd2gce`, not a result.

`TporsResult` and `TporvResult` are the one place where the integer is not a
SOFA status at all, and the wrapper says so instead of letting
`isWarning()`/`isError()` read it as one: `0` is the case where **nothing** was
written (`src/tpors.c:115-117`, `src/tporv.c:112-114`), so `status.isOk()` is
true while both solutions are `null`. A caller must read `first`/`second`, not
the status, to know whether there is an answer, and must not read `isWarning()`
as a warning either - every non-zero count is positive, so the usual case of one
useful solution answers it too. `TpxeResult` is the opposite case: both fields
are always written, because upstream clamps the divisor to `±1e-6` instead of
dividing by zero (`src/tpxes.c:19-27`, `src/tpxev.c:24-32`), so its status is a
report on a near-singular input and not of a missing answer.

**Four of the seven non-status `int` returns are typed, and each says what its
integer is.** `leap.getLeapSeconds` returns `LeapTableResult` whose
`status` documents itself as an entry count or `-1`, not a warning ladder
(`src/erfadatextra.c:33-37`); `leap.datini` returns the same shape for
`eraDatini`'s entry count, with the "already initialised" rule stated on the
call rather than inferred from the number; and `gnomonic.fromStandardCoordinates`
and `gnomonic.fromVector` return `TporsResult`/`TporvResult`, whose integers
`0`, `1` and `2` are upstream's **count of useful solutions** - none, only
`Soln. 1`, or both - decided near the poles by `(fabs(rsb) < 1.0) ? 1 : 2`
(`src/tpors.c:23-26,53-56,114`, `src/tporv.c:23-26,48-51,111`). Both outputs are
written whenever either is; a count of `1` says the second is not *useful*, not
that it is absent.
The three that stay on the raw route are `eraVersionMajor`, `eraVersionMinor` and
`eraVersionMicro`, whose only content is `2`, `0` and `1`.

### 3b. Value types

`Date2 { part_a, part_b, sum }` is the two-part date: **the sum is the value**
and the apportionment is arbitrary, per `src/jd2cal.c:33-46`. `TimeScale` is an
enum over `tai tt ut1 utc tcg tcb tdb` plus a `code`, and `calendar.dtf2d` /
`calendar.d2dtf` take it **instead of a string**, because upstream selects on
`strcmp(scale, "UTC")` (`src/dtf2d.c:99`). `Ellipsoid`, `ObservationType`,
`Vec3`, `Mat3`, `Pv`, `Nutation`, `Cip`, `Prec76Angles`, `PrecessionNutation`,
`PnResult`, `CalendarDate`, `GregorianDate`, `RoundedCalendarDate`, `TimeOfDay`,
`ObservedSpherical`, `ObservedPlace`, `EquatorialCoordinates`,
`EclipticCoordinates`, `Observatory`, `Astrom` and `ObservedAstrom` are the
calendar-and-astrometry value types, and the vector, matrix, angle, catalogue
and gnomonic namespaces add these: `LightDeflectingBody` (an alias for
`c.eraLDBODY`, like `LeapSecond`), `LightDeflection`, `PvModulus`, `PvDotProduct`,
`SphericalAngles`, `CartesianSpherical`, `PvSpherical`, `StandardCoordinates`,
`SphericalPair`, `StarMotion`, `StarMotionReduced`, `Fk5HipResult` and
`RefractionConstants`. `LeapSecond` is an **alias**, not a mirrored layout —
`pub const LeapSecond = c.eraLEAPSECOND;` — so there is no second struct to keep
in step and no field list to look for here.

Four of those records are named after what they hold rather than after the
function that fills them, and the names are the ones upstream uses for the same
shape: `SphericalAngles { theta, phi }` is `eraC2s`'s output, `CartesianSpherical`
adds `radius` from `eraP2s`, and `PvSpherical` carries `theta_rate`,
`phi_rate` and `radius_rate` beside the three angles for `eraPv2s`. Nothing
renames an upstream identifier; the grouping is the only thing this package
adds.

`Astrom` and `ObservedAstrom` are the two exceptions, and they are narrower than
upstream's `eraASTROM` on purpose. `eraApco13` writes sixteen of that record's
seventeen members: `eraApcs` writes `pmt`, `eb`, `eh`, `em`, `v`, `bm1` and `bpn`
(`src/apcs.c:142-170`), `eraApco` writes the other nine (`src/apco.c:182-220`),
and `phi`, declared at `src/erfa.h:31`, is assigned by nothing in `src/`.
`eraApio13` writes nine of them (`src/apio.c:140-166`) and leaves the other seven
as the caller's record already held them, which is what lets `eraAtciq` consume
it later (`src/atciq.c:75-84`). `Astrom` therefore names the sixteen that exist,
`ObservedAstrom` the nine `eraApio` produces, and the raw route still publishes
the whole record as `c.eraASTROM`. Publishing members nothing computes would
hand the caller undefined data; zeroing them would invent values upstream never
writes.

**Where the two records differ, and how a result says so.** `Apco13Result` and
`Apio13Result` are not two spellings of one thing. `Apco13Result.astrom` is an
`Astrom` — the sixteen members `eraApco13` actually assigns. `Apio13Result.astrom`
is an `ObservedAstrom` — the nine members `eraApio13` assigns
(`along`, `xpl`, `ypl`, `sphi`, `cphi`, `diurab`, `eral`, `refa`, `refb`). The
seven that are *not* there (`pmt`, `eb`, `eh`, `em`, `v`, `bm1`, `bpn`) are the
ICRS-side parameters; upstream would have taken them from a record the caller
prefilled, and this facade never hands the caller a record to prefill, so it
cannot publish them without inventing them. A caller that needs the full
17-member record reads and writes `c.eraASTROM` itself.

**Units are part of the contract, and they are not all the same.** Every field
that is not self-evidently an angle carries its unit in its own doc comment,
and the ones most often misread are:

| Where | Unit | Note |
|---|---|---|
| `Astrom.eb`, `Astrom.eh` | **au** | SSB→observer and Sun→observer vectors |
| `Astrom.em` | **au** | the Sun→observer **distance**, not a mass and not metres: `eraApcs` computes it as the modulus of the heliocentric observer vector, `eraPn(ph, &astrom->em, astrom->eh)` (`src/apcs.c:157-158`) |
| `vectors.ld`'s `observer_distance` | **au** | the observer-to-body distance upstream divides by (`src/ld.c:14-20,87-89`) |
| `Astrom.pmt` | Julian years | PM time interval, SSB |
| `ObservedAstrom.eral`, `.refa`, `.refb`, `.along`, `.xpl`, `.ypl` | radians | `.diurab`, `.sphi`, `.cphi` are dimensionless sines/cosines |
| `Astrom.bpn`, `Mat3` products | dimensionless | a rotation; orthonormal to its own precision |
| `Geodetic.height`, and therefore `Gc2gdResult.geodetic.height` | **metres** | never au and never radians (`src/gc2gd.c:42-43`) |
| `DatResult.delta_at` | **SI seconds** | ΔAT, not days |
| `Pv.position` / `Pv.velocity` | **au** / **au per day** | the shape every ephemeris here returns |
| `eraApco13` / `eraAtco13` `equation_of_origins` | **radians** | ERA − GST; *not* the equation of the equinoxes (§3c) |
| every `epoch` argument, and the return of `calendar.epb` / `calendar.epj` | **absolute Julian epoch** — the year plus fraction counted from 2000.0 | the whole `lt*` family subtracts 2000.0 internally (`src/ltpecl.c:13`, `src/ltpequ.c:84`), so passing "years from J2000.0" would silently compute the year 0 |

**Partial output is a first-class result, and each routine's shape is its
own.** No result type claims "all outputs present" or "all outputs absent" in
general. Where upstream writes nothing the typed field is `null`, so a caller
cannot read an unwritten double as if it were an answer; where upstream writes
a **defined residue** instead — a sentinel, a zero, or a real value under a
warning — that residue is what the field carries, because it is what the C
caller sees and inventing a `null` for it would be a second, different lie:

| Typed result | What a rejection leaves behind | What still computes |
|---|---|---|
| `Cal2jdResult` | `−1` bad year and `−2` bad month: `date` is **`null`**, upstream returns before either output is assigned (`src/cal2jd.c:68-69`) | **`−3` bad day: `date` is present.** The Julian Date *is* computed and written (`src/cal2jd.c:75-84`) |
| `Apco13Result` / `Apio13Result` / `Atco13Result` / `Atio13Result` | `−1` unacceptable date: every output field is `null` — `astrom`, `equation_of_origins`, `place` (`src/apco13.c:190,193`) | `0`, and `+1` dubious year — a warning, and the outputs are still there |
| `Gc2gdResult` | nothing is `null` — on `−1`/`−2` upstream writes the sentinel **`−1e9` into all three outputs** (`src/gc2gd.c:45-47,74-79`); its `−2` is documented as theoretically impossible, being only reached by folding a `gc2gde` error into `-2` (`src/gc2gd.c:69-71`) | `0` |
| `Gc2gdeResult` | `geodetic` is **`null`** for `−1` illegal flattening and `−2` illegal `a`: upstream validates the ellipsoid before writing anything and leaves the caller's own values exactly as they were (`src/gc2gde.c:44-46,76-77`) | `0` |
| `Gd2gcResult` | nothing is `null` — `eraGd2gc` validates no longitude, latitude or height (`src/gd2gc.c:45-47`), and **in all error cases it writes zeroes** (`src/gd2gc.c:48-49`); `−1` is an illegal ellipsoid identifier and `−2` guards against arithmetic exceptions | `0` |
| `Gd2gceResult` | nothing in practice — the `−1` guard is unreachable, see §3c | `0`; `−1` is documented as unreachable rather than manufactured |
| `EformResult` | nothing is `null` — on `−1` upstream writes `a = f = 0.0` before returning (`src/eform.c:87-89`); that is a zeroed result, not a sentinel | `0` |
| `Dtf2dResult`, `D2dtfResult` | every negative status writes nothing: `date` is `null` (`src/dtf2d.c:141-148`) | `+1`, `+2` and `+3` all still produce the value (§5) |
| `Timescale*Result` | `−1` unacceptable date: the result date is `null` | `0`, and any positive status, which is a warning whose value is preserved |
| `Epv00Result` | there is no negative status at all | `+1` for a date outside 1900–2100, still computed |
| `Plan94Result` | nothing is `null` — `−1` (illegal `np`) leaves a **zeroed** `pv` (`src/plan94.c:54-55`) | `+1` and `+2` both still return a position |

`rotation.earthRotationAngle` is the wrapper for `eraEra00` and lives in
`erfa.rotation`. It is not named `era00` because a Zig identifier cannot begin
with a digit.

**Two parameters that look like inputs and are not.**
`precession.ltpecl(epoch)` and `precession.ltpequ(epoch)` take **no vector
argument** and return a `Vec3`: upstream declares `double vec[3]`
(`src/ltpecl.c:4`) and `double veq[3]` (`src/ltpequ.c:4`), documents both as
returned values, and overwrites all three components
(`src/ltpecl.c:114-116`). Reading the array parameter as an input would be
wrong twice over.

By contrast `vectors.pn`, `vectors.pm`, `vectors.ld` and `precession.eors` do
take their vector or matrix **read-only** — `eraEors` reads `rnpb` and never
writes it (`src/eors.c:3,` body), `eraPm` returns the modulus of its argument
(`src/pm.c:3`, `src/erfa.h:504`), `eraPn` reads `p` and writes `u`
(`src/pn.c:3`), and `eraLd` reads `q` and `e` into temporaries
(`src/ld.c:4`) — so the wrapper takes `*const Vec3` / `*const Mat3` rather than
re-deriving the bound from the C declaration alone.

### 3c. Decisions the typed route is bound by

Each is traceable to upstream source:

- **A status is carried, never collapsed.** `0` is success, a positive value is
  a warning whose *value* is preserved, a negative value is an error. Upstream
  itself distinguishes the two signs (`src/dat.c:76-78`: the `+1` warning "is
  distinct from the error status `-1`"), and the numeric value matters —
  `eraDtf2d` returns `+1` *and* `+2` together (`src/dtf2d.c:58-65,129-131`).
- **Warnings propagate with lossy value semantics, and that is upstream's, not
  the wrapper's.** `eraUtcut1` collapses any negative child status to `-1` but
  copies a positive child status through unchanged
  (`src/utcut1.c:85-90`); several chains map everything to `-1`. A caller that
  wants to know *which* warning fired has to read the value, which is why the
  wrapper does not erase it.
- **Error results are sentinels, not NaN, and they differ per call.**
  `eraGc2gd` sets all three outputs to `-1e9` on error
  (`src/gc2gd.c:47,76-78`); `eraGd2gc` sets the vector to zeroes "in all error
  cases" (`src/gd2gc.c:48-49`); `eraEform` sets `a = f = 0.0` before its
  `return -1` (`src/eform.c:87-89`); `eraPlan94` returns `-1` for an `np`
  outside 1–8 with `pv` set to zeroes (`src/plan94.c:54-55`); `eraDat` returns
  ΔAT = 0 "in cases where a valid result is not available"
  (`src/dat.c:106`); and `eraCal2jd` still writes both outputs when it returns
  `-3`, documented as "bad day (JD computed)" (`src/cal2jd.c:24`). Nothing in
  the tree returns NaN as an error, so a caller cannot detect failure by
  testing for NaN. The typed route states, per function, what a rejected input
  leaves behind.
- **A rejected or warned-about call is not a fatal call.** `eraEpv00` returns
  `+1` for a date outside 1900–2100 and still computes
  (`src/epv00.c:22-24`); `eraPlan94` returns `+2` for non-convergence and still
  returns a position (`src/plan94.c:29`). Treating "non-zero" as failure throws
  away real results.
- **Two functions validate nothing.** `eraGd2gc` states "No validation is
  performed on the arguments elong, phi and height" (`src/gd2gc.c:45`), and
  `eraApco13` warns that "even unlikely" inputs are accepted and processed
  (`src/apco13.c:125`). The wrapper must not
  invent range checks the upstream contract does not have and then report them
  as ERFA errors.
- **Two ephemerides are not standards.** `eraPlan94` and `eraMoon98` say so in
  their own headers (`src/plan94.c:14`: "Not IAU-endorsed and without canonical
  status"). That is upstream's statement about its own routine; it is not an
  endorsement by this package and not a claim that they are wrong.
- **Epochs are years counted from 2000.0, not intervals from J2000.0.**
  `eraEpb` returns `2000.0 + (days since J2000.0) / 365.25` (`src/epb.c:16-22`)
  and `eraEpj` the same in TDB (`src/epj.c:53`), so `calendar.epb2jd(1957.3)` is
  late 1957 and its MJD is 35948, not 53948. The whole `lt*` family takes the
  same absolute TT Julian epoch (`src/ltpecl.c:13`, `src/ltp.c:12`,
  `src/ltpequ.c:84`) and subtracts 2000.0 internally, so passing the documented
  "years from J2000.0" of `0.0` would silently compute the year 0. The wrappers
  pass the value through unchanged and name the parameter `epoch`.
- **The equation of the origins is not the equation of the equinoxes.**
  `eraApco13` and `eraAtco13` return `eraEors(r, s)` (`src/apco13.c:220-221`,
  `src/atco13.c`), which is ERA - GST and carries the precession contribution
  (`src/eors.c:21-27`); `eraEo06a` is the same quantity
  (`src/eo06a.c`). `eraEe00`, `eraEe00a`, `eraEe00b`, `eraEe06a`, `eraEect00`
  and `eraEqeq94` are the equation of the equinoxes. The typed route names them
  apart: `Apco13Result` and `Atco13Result` publish
  **`equation_of_origins`**, and `precession.eors` takes the CIO locator `s` in
  **radians**, not an arcsecond-to-radian scale.
- **`eraLd`'s fifth argument is a distance, not a mass.** `src/ld.c:14-20,87-89`
  divides the deflection by it, and it is the observer-to-body distance in au;
  `vectors.ld` names it `observer_distance`.
- **`eraGd2gce` validates no flattening.** Its `-1` guard is
  `cos(phi)^2 + w^2 sin(phi)^2 <= 0` (`src/gd2gce.c:73-74`), a sum of
  non-negative terms that no finite argument drives to zero, so the status
  exists but no input reaches it and `Gd2gceResult.cartesian` is present on
  every real call.

### 3d. Five things in the vector, matrix and refraction surface that are not what their names suggest

Each of the five is traceable to one C expression, and each is a place where a
caller who reads only the name, or who asserts an exact algebraic identity,
writes a check that fails for arithmetic reasons. All five are stated here from
the source, and the facade exercise checks each at the precision upstream's own
expression supports.

**`vectors.pvxpv(a, a)` is zero in real arithmetic and not in floating point.**
`eraPvxpv` computes the position member as `a_p × a_p` and the velocity member as
`a_p × a_v + a_v × a_p` (`src/pvxpv.c:46-50`), and `eraPxp` forms each component
as a difference of two products — `ya*zb - za*yb` and its two siblings
(`src/pxp.c:43-45`). For identical operands the two products are equal, so each
component is `x - x`; that is exactly `0.0` in IEEE-754, and the *sum of two
cross products* with identical operands is exactly `0.0` for the same reason.
**If the compiler contracts a multiply-add** — computing `fma(ya, zb, -(za*yb))`
so the first product is not rounded before the subtraction — the component is no
longer `x - x` but `round(y*z - round(z*y))`, and the residual is the rounding
error of one product. The package therefore asserts the self-cross **velocity**
member to an absolute tolerance of `1e-14`, and it is the only member it
asserts that way:
`zig/api_exercise.zig:764-766`. The exact-`== 0.0` assertions on
`pvmpv(a, a).position[0]` and `2.0 *` on `pvppv(a, a).position[1]`
(`zig/api_exercise.zig:762-763`) are sound, because `eraPmp` and `eraPpp` are
plain componentwise `-` and `+` (`src/pmp.c`, `src/ppp.c`) with no product to
round. This is a property of the compiled library, not a claim about any one
compiler: the residual is bounded by one ulp of the operands and is zero when
no contraction happens.

**`vectors.pvu(dt, pv)` and `vectors.pvup(dt, pv)` need not agree, and the
velocity member is a copy.** `eraPvu` is `eraPpsp(pv[0], dt, pv[1])` followed by
`eraCp(pv[1])` (`src/pvu.c:37-38`), so it updates the position by `p + dt·v` and
copies the velocity **unchanged** — the velocity is not scaled by `dt`. `eraPvup`
computes only the position, as `pv[0][i] + dt * pv[1][i]`
(`src/pvup.c:37-39`), in one expression a compiler may contract into a single
`fma`. `eraPpsp` computes `s*b` into a temporary with `eraSxp` and *then* adds
(`src/ppsp.c`), so `eraPvu` rounds `dt·v` before the sum where `eraPvup` may not.
The two routines can therefore differ in the last bit, and neither is "more
correct". The exercise checks `pvu`'s position against `p + 0.5·v` at `1e-14`
and `pvup` only for finiteness (`zig/api_exercise.zig:753-756`). The time units
of `dt` are the caller's: upstream's own note is "the time units of `dt` must
match those of the velocity" (`src/pvu.c:23`), and nothing in this package
converts anything.

**`vectors.pap` is a position angle, not a separation, and the two families are
not interchangeable.** `eraPap` returns the *bearing* of `b` as seen from `a`,
in `[-pi, pi]`, north zero and east positive (`src/pap.c:20-24,84`), and returns
zero when either vector is null or the two directions are the same
(`src/pap.c:28-29,56-59,80`). `eraPas` is the same quantity computed from
longitude and latitude (`src/pas.c:38-42`). The separation family is separate:
`eraSepp` returns the angle *between* two directions in `[0, pi]`, using
`atan2(|a×b|, a·b)` (`src/sepp.c:44-46`), and `eraSeps` is its
longitude/latitude form. A position angle and a separation are different
quantities — for two points a degree apart, one is near zero and the other near
one degree — and `vectors.pap` agreeing with `vectors.sepp` would be a bug, not a
pass. What *does* hold, and what the exercise checks, is that each
 **vector**-argument routine agrees with its own **angle**-argument partner:
`pap(p, q) == pas(theta_p, phi_p, theta_q, phi_q)` and
`sepp(p, q) == seps(...)`, both at `1e-12` (`zig/api_exercise.zig:769-778`).
`eraPap` is ill-defined when `a` is at a pole (`src/pap.c:31`); the package says
so and does not substitute a value.

**`matrices.rotateX/Y/Z` start from the identity because upstream's rotations are
in-place and read what is already there.** `eraRx`, `eraRy` and `eraRz` take an
`r-matrix` as *given and returned* (`src/rx.c:14-15`, and the same note in
`ry.c` and `rz.c`) and each reads rows it then rewrites — `eraRx` mixes rows 1
and 2 into each other (`src/rx.c:43-55`), `eraRy` rows 0 and 2
(`src/ry.c:43-55`), `eraRz` rows 0 and 1 (`src/rz.c:43-55`). A row they never
touch is left exactly as the caller left it, so calling `eraRx` on an
uninitialised matrix yields a matrix with an arbitrary first row. The typed
route therefore seeds the identity first: each of `matrices.rotateX`,
`rotateY` and `rotateZ` calls `identity()` and hands that to upstream
(`zig/root.zig:3262-3280`), and `eraIr` writes all nine entries rather than
only the diagonal (`src/ir.c:20-28`), so the seed is complete. `eraRv2m` has
the same shape from the other side: a zero rotation vector gives the identity
back, because `phi = 0` leaves `s = 0` and `f = 0` so every off-diagonal term
vanishes and each diagonal entry is `c = 1` (`src/rv2m.c:42-60`, and upstream's
own note 2 at `src/rv2m.c:23-24`), which the wrapper documents rather than
treating as an error.

**`atmosphere.refractionConstants` returns a negative second constant, and
upstream validates its own inputs.** `eraRefco` computes
`*refa = gamma * (1 - beta)` and `*refb = -gamma * (beta - gamma / 2)`
(`src/refco.c:202-203`), where `beta = 4.4474e-6 * tk` (`src/refco.c:198`) and
`tk` is the absolute temperature. For any ordinary observing temperature
`beta` is around `1.26e-3` and `gamma` around `2.8e-4`, so `beta` exceeds
`gamma / 2` by nearly a decade and **`refb` is negative** — upstream's own pinned
oracle value for `800 hPa, 10 °C, rh 0.9, 0.4 µm` is `-0.2598658261729343970e-6`
(`src/t_erfa_c.c:8006`). The sign is a property of the model, not an error, and
the wrapper neither flips it nor takes an absolute value. Two things this
package does **not** do here: it does not report a status, because `eraRefco`
returns `void` and none exists; and it does not invent range checks, because
upstream applies its own — the arguments are clamped with `ERFA_GMAX`/`ERFA_GMIN`
to temperature `[-150, 200]`, pressure `[0, 10000]`, humidity `[0, 1]` and
wavelength `[0.1, 1e6]` (`src/refco.c:167-174`, `erfam.h:106-109`), silently,
with no diagnostic. A caller who passes a pressure of `-5` gets the answer for
`0`, not an error. The exercise states only what the source guarantees —
`refa > 0` and `refb < 0` at `1010 hPa, 10 °C, rh 0.5, 0.55 µm`
(`zig/api_exercise.zig:679-688`) — and does not assert the clamped values,
because upstream states no bounds on its inputs and this package adds none.

### 3e. The one breaking correction in this wave: `vectors.s2xpv` returns a `Pv`

`vectors.s2xpv(s1, s2, pv)` returns **`Pv`**. The first version of the typed
route declared it `Vec3`, and that was wrong in a way no name could carry:
`eraS2xpv` writes **six** doubles — its output parameter is declared
`double spv[2][3]` (`src/erfa.h:517`) and it fills them with one `eraSxp` call
per member (`src/s2xpv.c:31-32`). The old wrapper allocated a `Vec3` result and
passed `&result` for that parameter, so the callee wrote three doubles past the
end of a three-double object. **`s2xpv` is not a vector sum**: the old doc
comment called it `s1 * p + s2 * v`, and there is no addition anywhere in
`src/s2xpv.c`. What it computes is `position * s1` and `velocity * s2`, each
componentwise, returned together.

**What found it, and what did not.** The runtime-loaded `ReleaseSafe` run
recorded in §9a.2 — `zig build smoke test -Druntime=true -Dlinkage=static
-Doptimize=ReleaseSafe`, exit **1** — reports `60/60 tests passed` and `smoke
success` and then aborts in the facade exercise at `vectors.s2xpv`:
`Illegal instruction`, `@trap()` in the compiler runtime, inside the `s2xpv`
dispatch stub (`dispatch.zig:67`), reached from the old `api_exercise.zig:738`
(`local://foundation-resumed-erfa-loaded-static-ReleaseSafe.json`). Nothing
earlier observed it: the linked `Debug` row in §9a.2 passes `60/60` with the
exercise green, and `tests.zig` had no test for `vectors.s2xpv` at all, so the
only check the routine had was the exercise's finiteness loop — which reads
three of the six numbers the callee wrote and cannot see the three written past
the end.

**What a caller changes.** The result is read as two members:

```zig
const scaled = erfa.vectors.s2xpv(3.0, -0.5, pv);
// scaled.position == 3.0 * pv.position, scaled.velocity == -0.5 * pv.velocity
```

There is no shim, no alias and no deprecated overload: a caller that indexed
the old three-component result indexes one of the two members instead. The
facade exercise now checks all six values against the operands with exact
equality rather than for finiteness (`zig/api_exercise.zig:738-751`), and
`tests.zig` carries one new case for the routine — *"vectors.s2xpv: two scalars,
two members, six results"* (`tests.zig:1259-1289`) — which checks all six
exactly, with different scales, one of them negative, on operands chosen so
the products do not round (`eraSxp` is one multiply per component,
`src/sxp.c:27-29`). The member counts in the tables above are unchanged: 197
members, 197 functions, `eraS2xpv` among the 31 in `erfa.vectors`.

**Status.** `SOURCE-CONFIRMED` for the shape and the arithmetic — `Pv` is
`extern` with exactly the `double[2][3]` layout this call needs
(`zig/root.zig:701-718`, `pvPointer` at `:739-741`), and `sxpv` is the sibling
that already passed a `Pv` in both directions (`zig/root.zig:2619-2623`). The
gate that found the defect is quoted above; **no gate has run since the
change**, and every current row in §9a.2 predates it.

## 4. Consumer costs, measured

| Cost | Measured |
|---|---|
| C translation units compiled | **249** core `.c` files (2 more for the upstream test programs) |
| Core C source | 1,963,780 bytes; `src/` total 2,254,346 bytes |
| Public headers installed | 4 files, 36,339 bytes total |
| Headers to translate | 4 — `erfa.h`, `erfam.h`, `erfaextra.h`, `erfadatextra.h` |
| Link dependencies | `libm`, and nothing else (`meson.build:32`, `configure.ac:26`) |
| **Required compilation backend** | **LLVM** — `.use_llvm = true` on every **Zig** executable/test root that imports the module, or `-fllvm` on the command line. Not optional for such a root, and not a preference; §1a has the discriminator receipt and the exact consequences. A pure C program linking `liberfa.a` has no Zig root and is unaffected |
| Installed by `zig build` | `liberfa.a`, the 4 public headers, `LICENSE`, `INFO` (`b.installArtifact` / `b.installFile` in the default step of `build.zig`). The smoke example and the facade exercise are **compiled but not installed** — `b.getInstallStep().dependOn(&exe.step)` is a `Compile.step` dependency, not an install |
| Generated build input | one header, `config.h`, written deterministically at build time |
| Heap use in the core | **none** — a whole-tree scan for `malloc`/`calloc`/`realloc`/`free`/`alloca`/`strdup` found nothing; every result is written into caller storage |
| Compile-time concentration | `src/epv00.c` 150,627 B, `src/xy06.c` 132,290 B, `src/nut00a.c` 118,469 B, `src/dtdb.c` 62,193 B, `src/moon98.c` 23,973 B — these five dominate the graph |

What that means for a consumer: **no allocator, no deinitialisation, no
free-then-reuse ordering to get right.** Every routine writes through pointers
the caller owns, and a caller that wants a fixed-size scratch buffer can own it
on the stack. That is a real cost saving and it is also a real constraint: the
caller must supply buffers of the right size, and several routines take
caller-allocated arrays as `double[2][3]` or `double[3][3]` by pointer.

The price is compile time and archive size. 249 translation units is the
dominant cost of this package; a cross-target `check` compiles all six required
targets, and the 53-platform `cross-test` matrix compiles each of its platforms
too. There is no way to make that cheaper without dropping core files, and
dropping core files is exactly what this package does not do.

**`config.h`.** Upstream generates it; this package writes it as a
deterministic build step from five recorded values — `PACKAGE_VERSION
"2.0.1"`, `PACKAGE_VERSION_MAJOR 2`, `_MINOR 0`, `_MICRO 1`, `SOFA_VERSION
"20231011"` (`meson.build:3,24-29`, `configure.ac:5,23`, `m4/erfa-numver.m4`) —
and defines `HAVE_CONFIG_H` on both the compile line and the translation line.
Only `src/erfaversion.c` consumes it (`src/erfaversion.c:15-17`).

**The translation has two routes, and only NetBSD differs.** `zig translate-c`
parses C with **Aro**, which preprocesses as well as parses, so `zig/translate.h`
can be read either way round. `aggregateRoute` in `build.zig` picks per target
between:

- **Aro preprocesses it for itself** — on every target but NetBSD, exactly as
  before this fork touched anything.
- **The target's own C preprocessor expands it first** (`zig cc -E -dD`, with
  `-target <triple>` when the target is not native, and a `-MD`/`-MF`
  dependency file), and Aro parses what that wrote — on NetBSD only.

Both routes read this repository's four public headers on the same include
path with the same macros and the same generated `config.h` directory, and the
only thing that changes is *which preprocessor has to understand the target's
C library*. Nothing is stubbed, narrowed, renamed or substituted on either
route, and all 35 `erfam.h` macros still reach Zig as constants — which is why
the NetBSD route passes `-dD`: without it the expansion carries no `#define`
lines and `pub const c` would silently lose `ERFA_DJM0`, `ERFA_DAYSEC` and
`ERFA_WGS72`.

The condition is the **OS tag** (`target.result.os.tag == .netbsd`), not a list
of nine triples, because the whole family shares one header and one cause.
`erfa.h:15` reaches exactly one system header, `math.h`; NetBSD's
`generic-netbsd/sys/cdefs.h:431-432` routes `__END_DECLS` through
`__BEGIN/END_PUBLIC_DECLS`, which `:411-416` defines as `extern "C"` framing
around `_Pragma("GCC visibility push(default)")` and
`_Pragma("GCC visibility pop")`. `<math.h>` closes every declaration block with
`__END_DECLS`, so every NetBSD translation drags two `_Pragma` operator
invocations in, and Aro destringizes each into a `#pragma` line it then hands
to the parser as C. The first 53-platform run (§9a) reported **five errors at
`math.h:607`** on all nine NetBSD targets and on no other, with the C archive
itself compiled.

**The route is now observed, and the second observation cost three lines of
`zig/translate.h`.** `zig build check -Dtarget=aarch64-netbsd -j2 --summary all`
reports `Build Summary: 11/11 steps succeeded`, with a
`preprocess erfa translate.h` step sitting under the translation
(`local://foundation-matrix-erfa-netbsd-preprocess-check-r2.log`). The first
re-gate failed on something the front end fixed but did not carry: with `-dD`,
`generic-netbsd/arm/cdefs.h:62-63` spells `__ALIGNBYTES` as
`sizeof(__int128_t) - 1` on the `__ARM_PCS_AAPCS64` branch — the branch
AArch64 takes, because `__ARM_PCS_AAPCS64` is one of the compiler's own
predefines — and nothing in the expansion declares the typedef, so the
translated Zig named an undeclared identifier
(`local://foundation-matrix-erfa-netbsd-preprocess-check-r1.log:3-6`). The
bridge is three lines in a fork-authored header and nothing else: under the
compiler's own capability macro `__SIZEOF_INT128__`, `zig/translate.h`
restates `__int128_t` and `__uint128_t` ahead of the four includes. That
declares the **compiler's builtin 128-bit integer extension**, which Clang
declares next to `__int128` itself and no header repeats; it is not a patch to
native code. **No `.c` and no `.h` upstream file is touched**, `x86_64-netbsd`
spells `__ALIGNBYTES` as `sizeof(long) - 1` and needs none of it, the 32-bit
NetBSD targets leave the guard false, and a target without `__int128` declares
neither. The corrected 53-platform run then builds all nine NetBSD targets.

## 5. Two-part dates, UTC quasi-JD, and the errors you get instead

These are the places where "obvious" code is silently wrong.

**Two-part dates.** A date is a `double` pair whose **sum** is the value; the
apportionment is arbitrary. Upstream gives four equivalent splits of
JD 2450123.7 (`src/jd2cal.c:33-42`) and recovers resolution with
Kahan–Neumaier compensated summation so the result does not depend on which
split the caller used (`src/jd2cal.c:44-46,59-60`). `eraCal2jd` always writes
the MJD zero-point into `*djm0` — `ERFA_DJM0`, 2400000.5 (`src/cal2jd.c:16,80`)
— and puts the MJD in `*djm`.

**`eraDtf2d` can hand back a fraction outside `[0,1)`.** It sets
`*d1 = dj; *d2 = time;` (`src/dtf2d.c:143-148`) where `time` is computed by
dividing the seconds-of-day by a `day` that has been *lengthened* on a leap
second (`src/dtf2d.c:118-120`). When the seconds exceed the end-of-day limit it
returns `+2` and the value is still produced; on a leap second the limit is
61.0, or 59.0 for a negative leap (`src/dtf2d.c:58-61`). A wrapper that
clamps, asserts or re-splits this value changes the answer. The rule that
applies is upstream's own: only for the continuous scales TAI, TT, TCG, TCB and
TDB is `d1 + d2` strictly a Julian Date; for UT1 and UTC "the difference
between two such results cannot be interpreted as a precise time interval"
(`src/dtf2d.c:67-72`).

**Scale names are case-sensitive and exact.** `eraDtf2d` and `eraD2dtf` select
UTC behaviour with `strcmp(scale, "UTC")` (`src/dtf2d.c:99`,
`src/d2dtf.c:97`). A facade must not accept `"utc"`.

**The calendar is proleptic Gregorian with a floor.** `eraCal2jd` rejects years
below `IYMIN = -4799` with `-1` (`src/cal2jd.c:29,57,68`) and does not take
account of the dates on which the Gregorian calendar was adopted
(`src/jd2cal.c:48-51`). `eraJd2cal` accepts up to 1e9 and rejects below
−68569.5 with `-1` (`src/jd2cal.c:30-31`). There is no "1582 gap" status in this
implementation — that rejection is not in the ladder upstream ships.

**`eraDat` has a dated cliff.** `src/dat.c` contains
`if (iy > IYV + 5) j = 1;` with `enum { IYV = 2023 }` (`src/dat.c:126`). Every
call with a year of **2029 or later** returns the "dubious year" **warning**
`+1` and still computes the answer (`src/dat.c:69-78`). As of 2026-10-03 that
is three years out. It is a warning, not an error, and it is a property of the
compiled-in table, not of the calendar.

**Status ladders actually present**, all read from the sources:

| Function | Ladder |
|---|---|
| `eraCal2jd` | `0`; `-1` bad year (JD not computed); `-2` bad month (JD not computed); `-3` bad day (**JD computed**) — `src/cal2jd.c`, `src/erfa.h` |
| `eraJd2cal` | `0`; `-1` unacceptable date — `src/jd2cal.c:23-26` |
| `eraDtf2d` | `+3`; `+2` time after end of day; `+1` dubious year; `0`; `-1`…`-6` — `src/dtf2d.c:29-35` |
| `eraDat` | `+1` dubious year; `0`; `-1`…`-5`; with several errors the **first detected** wins — `src/dat.c:53-61,99-104` |
| `eraEpv00` | `0`; `+1` outside 1900–2100, never negative — `src/epv00.c:22-24` |
| `eraPlan94` | `-1` illegal `np` (pv zeroed); `0`; `+1` year outside 1000–3000; `+2` failed to converge — `src/plan94.c:26-29,54-55,151-154` |
| `eraGc2gd`, `eraGd2gc`, `eraGc2gde`, `eraGd2gce` | `0`; `-1`; `-2` — all five GeodeticGeocentric routines return a status |
| `eraEform` | `0`; `-1` — writes `a = f = 0.0` |
| `eraTpors`, `eraTporv` | **solution count** `0`, `1`, `2` — not a status — `src/tpors.c:23-26`, `src/tporv.c:23-26` |
| `eraGetLeapSeconds` | entry count `> 0`; `-1` internal error — `src/erfadatextra.c:33-37` |

## 6. The leap-second table: borrow, retain, and how to update it

This is the one place in the API with an ownership question, so it is stated
in full.

**Storage.** `src/erfadatextra.c:22-23` holds the active table as
`static ERFA_THREAD_LOCAL eraLEAPSECOND *changes;` and
`static ERFA_THREAD_LOCAL int NDAT = -1;`. `ERFA_THREAD_LOCAL` is selected by
the macro chain at `src/erfadatextra.h:38-50`: C++11/C23 `thread_local`, then
C11 `_Thread_local`, then MSVC `__declspec(thread)`, then GCC/Clang `__thread`,
then **empty**. Upstream's stated purpose is thread safety
(`src/erfadatextra.h:26-37`).

**`eraGetLeapSeconds` borrows.** It returns a pointer to that active table and
its length, with no copy (`src/erfadatextra.c:46-47`). The pointer stays valid
until the table is replaced or reset; the wrapper must present it as a borrow
and must not invalidate a returned borrow, and must not hand back a copy of
data it does not own.

**`eraSetLeapSeconds` retains the caller's pointer.** It stores the pointer it
is given with no copy and no check — its own note reads "*No* sanity checks are
performed" (`src/erfadatextra.c:61`), and a `count <= 0` resets to the built-in
table (`src/erfadatextra.c:56-58,64-65`). So the lifetime and the bounds of
whatever was installed are the **caller's** obligation after the call. The
wrapper asserts no ownership and documents this rather than pretending to own a
buffer it was handed.

**Which thread, and for how long.** The storage above is declared
`ERFA_THREAD_LOCAL` at this pin; at the `v2.0.1` tag the same two variables were
plain `static`, i.e. process-global mutable state. Between those two ends the
answer is the branch the target's dialect selected (see §7), so the statements
below are per-thread where that chain selected a real branch and per-process on
the empty one. Consequences a caller must plan for:

- A borrow is invalidated by a replacement or reset **on that thread only**, and
  only that thread's calls are affected - on the branches that give
  thread-local storage at all.
- A table handed to `eraSetLeapSeconds` must stay alive and unmodified for as
  long as any `eraDat` call can run on that thread. Nothing copies it, and
  nothing would notice if it went away.
- Passing a null pointer with `count <= 0` is the reset to the built-in table
  (`src/erfadatextra.c:56-58`).
- No ownership is asserted, there is no `deinit`, and there is nothing for a
  caller to free.

**`eraDat` sees a replacement made on its own thread.** `eraDatini`
(`src/erfadatextra.c:68-94`) reads the *calling thread's* `changes` and `NDAT`
and hands them straight back, and `src/dat.c:202` calls it on **every**
invocation of `eraDat`: the `int NDAT;` and `eraLEAPSECOND *changes;` declared at
`src/dat.c:199-200` carry no `static` and sit in the compound block that opens
at `src/dat.c:124`, so they are automatic locals re-initialised on each call —
unlike `drift` at `src/dat.c:129` and `_changes` at `src/dat.c:150`, which are
declared `static const` inside that same body. A later `eraSetLeapSeconds` is
therefore visible to the next `eraDat` on the thread that made it.

The only mutable state on this path is the pair of variables above: `_changes`
and `drift` are `static const` and read-only, and every write goes into them
(`src/erfadatextra.c:64-65`). That pair is per-thread on a real
`ERFA_THREAD_LOCAL` branch, so there is nothing there to race over; on the empty
branch it is one process-wide pair and there is.

**The data itself** is compiled in, not fetched. `src/dat.c:150` holds **42**
leap entries (1960-01-01 at 1.4178180 s through 2017-01-01 at 37.0 s) and
`src/dat.c:129` holds **14** drift rows for the pre-1972 era. There is no data
file and nothing is opened at build or run time.

**The index boundary: a replacement table is not just "newer entries".**
This is the sharpest trap in the whole API and it is invisible from the
signature. `eraDat` finds the preceding table entry with a **positional**
search and then applies the pre-1972 drift correction by the **same index**:

```c
   for (i = NDAT-1; i >=0; i--) {                       /* src/dat.c:231-233 */
      if (m >= (12 * changes[i].iyear + changes[i].month)) break;
   }
   if ( i < 0 ) return -5;                              /* src/dat.c:235-236 */
   da = changes[i].delat;                               /* src/dat.c:239     */
   if ( i < NERA1 ) da += (djm + fd - drift[i][0])
                           * drift[i][1];                /* src/dat.c:241-242 */
```

`NERA1` is 14, derived from the 14-row `drift` table
(`src/dat.c:129-147`). So:

- **`i < 14` is a position, not a year.** A drift rate is added to whichever
  row happens to sit at that position. Move the historical rows and the drift
  model silently attaches itself to a modern one.
- **The search requires ascending order.** It scans from the end and stops at
  the first `m >= 12*year + month`, so an unsorted table yields an entry that
  is simply not the latest one before the date.
- **`changes[0]` is the pre-UTC boundary.** `if (iy < changes[0].iyear)
  return 1;` (`src/dat.c:222`) compares against the **first row**, so a table
  that starts in the modern era makes every historical date return the warning
  `+1` with a zero ΔAT.

**So a valid replacement is "the whole built-in table plus appended modern
rows".** The first fourteen entries must be the built-in ones —
`{1960,1}`, `{1961,1}`, `{1961,8}`, `{1962,1}`, `{1963,11}`, `{1964,1}`,
`{1964,4}`, `{1964,9}`, `{1965,1}`, `{1965,3}`, `{1965,7}`, `{1965,9}`,
`{1966,1}`, `{1968,2}` (`src/dat.c:151-164`), followed by `{1972,1}` onward —
and the new leap seconds are appended at the end, in ascending
`12*iyear + month` order. **A two-row modern table is not a valid replacement
even though it is correctly sorted**: it silently re-points the drift model,
it moves the pre-UTC boundary to 2015, and every date before it returns `+1`.
This package's own test builds its replacement exactly this way — borrow the
built-in table, copy all of it into caller storage, append
`{2020,1,38.0}` and `{2022,7,39.0}` — and that is the pattern to copy
(`tests.zig:513-543`).

**Copying is the caller's job, and so is the lifetime.** Read the built-in
table with `getLeapSeconds`, copy the whole of it into storage the caller
owns, append, and hand **that** to `setLeapSeconds`. The slice must stay alive
and unmodified until the next replacement or reset on the same thread; mutate
it only *between* calls, never during one, because `eraDat` re-reads the
retained storage on every invocation. Nothing is copied by the library, so
nothing is freed by it either — there is no `deinit`, and passing `null` is
the reset.

That retention is observable rather than promised: the test writes `40.0` into
its own caller storage **between** two `dat` calls and reads `40.0` back from
the next one, which no copy-taking implementation could do
(`tests.zig:533-535`).

**Updating it is an upstream change, and this package does not fake one.**
Upstream's own procedure is written into the doc block at `src/dat.c:14-42`:
add a line to the initialiser set, set `IYV` to the current year, update the
"Latest leap second" comment (currently `2016 December 31`), and set the "This
revision" comment (currently `2023 January 17`); the `IYV` bump is required on
every re-issue even with no new leap second. Those bytes are upstream-owned and
covered by `UPSTREAM.sha256`. The fork's contribution is that they can be
updated by re-pinning and re-measuring the manifest, without waiting for a
distribution to ship a new tarball. Until upstream moves, a caller that needs a
newer table installs one itself with `eraSetLeapSeconds` and owns the lifetime
from that moment.

## 7. No system mode

This wave defines **no** system-integration option, so there is no system gate
and none is claimed. `erfa.pc.in` is never executed as a configure template;
`build.zig`'s `addPkgConfig` **reads it** and substitutes it in Zig, so its field
names, their order and upstream's own `Name:`/`Description:`/`Libs:` spellings
stay upstream's, with `@prefix@` rendered as `${pcfiledir}/../..` so the
installed file is relocatable. That writes `lib/pkgconfig/erfa.pc` for a
**source-built** output, which is metadata describing this package's own
install and not a system library. The source pin and the bounded contracts of
this wave stay exactly as they are; a later wave that adds a system mode has to
translate the **real selected installed headers** rather than shipping bundled
headers against an older installed library, and it may not quietly relax the
source pin.

Two portability questions belong here, not to §9. One is answered as far as a
compile can answer it; one is still open, and neither is a limitation of this
package:

- **Whether the libc-less `aarch64-macos-none` supplies `math.h`, `string.h`,
  `stdlib.h` and `float.h` at all. Answered, as far as `check` can answer it.**
  The six-target `check` (`zig build check -j2 --summary all`,
  `local://foundation-matrix-erfa-six-baseline.log`) compiles
  `aarch64-macos-none` to completion — library, test, facade exercise, smoke
  example and **both** upstream validation programs — `Build Summary: 55/55
  steps succeeded`. Every one of those headers therefore resolves for the
  libc-less target, including `<stdio.h>` for the oracle programs. What that
  settles is the header question; nothing has *run* there, so no runtime claim
  is made. The 53-platform table still names `aarch64-macos`, which is a
  *different* target, and the two must not be read as one result.
- **Which `ERFA_THREAD_LOCAL` branch `wasm32-wasi` takes**
  (`src/erfadatextra.h:38-50`). The 53-platform run records `wasm32-wasi` as
  **build pass / runtime unavailable** (`build_only`), and the six-target
  `check` compiles it without running it. A successful compile shows the chosen
  spelling was *accepted*; it does not show which of the five branches was
  taken, and it certainly does not show the leap-second state is per-thread at
  run time. The empty-definition branch would compile and run without a
  diagnostic. Still open, and open for the same reason it always was: no
  runner.

## 8. Licensing in one paragraph

The upstream files are BSD-3-Clause with the SOFA derivation preamble, and
`INFO` carries the IAU SOFA Board's relicensing permission — both shipped
verbatim. Four upstream files declare themselves **not** derived from SOFA and
one test file declares that and then carries the SOFA-derivation footer
anyway; all of that is itemised by path and line in `NOTICE.md`. This package
makes **no** SOFA endorsement claim: clause 3 of `LICENSE` bars using the SOFA
Board's, the IAU's or its contributors' names to endorse derived products, and
nothing here does. Every file this fork authored — build files, Zig sources,
tests, the consumer, the workflow, the Nix packaging and the provenance
documents — is **`BSD-3-Clause`**, granted by the package owner directly for
those additions; ERFA's grant does not reach them and never did. The
authorization, the SPDX identifier and the boundary are in `FORK-LICENSE.md`,
and the per-file inventory is `NOTICE.md` §4. Earlier revisions of this
paragraph said "no licence asserted"; that described the state before the
authorization and is superseded by it. `README.upstream.md` is **not** one of
the fork's files: it is a byte-for-byte preserved copy of upstream's
`README.rst`, so it keeps upstream's terms (`NOTICE.md` §3a).

**One carried upstream file is edited, on purpose.** `.gitignore` keeps all 24
of upstream's patterns byte-for-byte and in their original order, and this
fork appends `!/m4/` and `!/m4/erfa-numver.m4` — upstream's `/m4/` would
otherwise swallow `m4/erfa-numver.m4`, which is upstream **source** that this
package ships, lists in `.paths` and digests — plus the six Zig build-output
patterns and their `consumer/`-anchored equivalents. That makes the file
intentionally non-identical, so it is **deliberately absent from
`UPSTREAM.sha256`** and from the unmodified-paths diff in `verify.yml`, and the
append is recorded in `NOTICE.md` §4 and `FORK-NOTES.md` entry 13 instead of
being hidden by re-recording a digest over the edit. `sha256sum -c
UPSTREAM.sha256` covers 268 files and **passes** (§9a). No `.c` and no `.h`
file is patched.

## 9. Gate record

### 9a. Observed

Each row is one driver run. The rows are grouped: the first table is the
2026-10-03 driver matrix, taken against **the tree before the contract
migration**, and the second is the 2026-10-04 contract wave, taken against the
migrated tree. Each row names its retained log. Nothing below is claimed beyond
what that evidence carries, and a row in the first table is not evidence about
the tree as it now stands.

| Gate | Command | Optimize / target | Exit | Evidence |
|---|---|---|---:|---|
| **install + tests + facade exercise + smoke + consumer + upstream validation** | `zig build install test smoke consumer upstream-test -j2 -Doptimize=Debug --summary all --prefix …/erfa/install` | Debug / native | **0** | `local://foundation-matrix-erfa-current-debug-r1.log` — `Build Summary: 24/24 steps succeeded; 51/51 tests passed` |
| **tests + exercise + smoke + consumer + upstream validation** | `zig build test smoke consumer upstream-test -j2 -Doptimize=ReleaseSafe --summary all` | ReleaseSafe / native | **0** | `local://foundation-matrix-erfa-releasesafe-native.log` — `Build Summary: 20/20 steps succeeded; 51/51 tests passed` |
| **tests + exercise + smoke + consumer** | `zig build test smoke consumer -j2 -Doptimize=ReleaseFast --summary all` | ReleaseFast / native | **0** | `local://foundation-matrix-erfa-releasefast-native.log` — `Build Summary: 15/15 steps succeeded; 51/51 tests passed` |
| **tests + exercise + smoke + consumer** | `zig build test smoke consumer -j2 -Doptimize=ReleaseSmall --summary all` | ReleaseSmall / native | **0** | `local://foundation-matrix-erfa-releasesmall-native.log` — `Build Summary: 15/15 steps succeeded; 51/51 tests passed` |
| **six-target `check`** | `zig build check -j2 --summary all` | default optimize / all six | **0** | `local://foundation-matrix-erfa-six-baseline.log` — `Build Summary: 55/55 steps succeeded` |
| **`check` on a NetBSD target** | `zig build check -Dtarget=aarch64-netbsd -j2 --summary all` | default optimize / `aarch64-netbsd` | **0** | `local://foundation-matrix-erfa-netbsd-preprocess-check-r2.log` — `Build Summary: 11/11 steps succeeded` |
| **53-platform `cross-test`, after the NetBSD route** | `cross-test` from the package root, `zig-build` profile | default optimize / 53 targets | **0** | `local://foundation-matrix-erfa-cross-corrected-summary.json`, run id `20261003-194646-57707-28197` |
| **installed C consumer, compile** | `zig cc -std=c99 -I …/erfa/install/include erfa-installed-c-current.c …/erfa/install/lib/liberfa.a -lm -o …/erfa-installed-c-current` | n/a / native | **0** | `local://foundation-matrix-erfa-installed-c-current-compile.log` |
| **installed C consumer, run** | the binary it produced | n/a / native | **0** | `local://foundation-matrix-erfa-installed-c-current-run.log` — prints `public C surface compiled, linked and ran` |
| **provenance digests** | `sha256sum -c UPSTREAM.sha256` | n/a | **0** | `local://foundation-matrix-erfa-provenance-checksums.log` — 268 files, every line `OK` |
| **`zig fmt` over the fork's Zig files** | `zig fmt build.zig build.zig.zon tests.zig smoke.zig zig/root.zig zig/api_exercise.zig consumer/build.zig consumer/build.zig.zon consumer/src/main.zig` | n/a | **0** | `local://foundation-matrix-erfa-fork-zig-format.log` — nine files, exit 0, no diagnostics and nothing rewritten; the receipt records the nine paths the run was given |
| backend discriminator, default backend | `zig run -ODebug … liberfa.a …` | Debug / native | 0 | `local://foundation-matrix-erfa-boundary-isolation.log` |
| backend discriminator, `-fllvm` | same argv with a leading `-fllvm` | Debug / native | 0 | `local://foundation-matrix-erfa-boundary-llvm-discriminator.log` |

### 9a.2 Observed against the migrated tree

The typed route grew from 99 members to 197 and `tests.zig` from 51 tests to 61
during this wave, so every row above that reports a test count describes the
earlier surface. These rows are the current ones, and each is scoped to what its
receipt prints.

| Gate | Command | Optimize / target | Exit | Evidence |
|---|---|---|---:|---|
| **full SDK test suite + facade exercise + smoke** | `zig build test smoke -j2 --summary all --prefix …/erfa-static` | Debug / native, linked, `-Druntime=false` | **0** | `local://foundation-contract-erfa-current-full-gate-after-aberration-and-spin-repair.log` — `Build Summary: 12/12 steps succeeded; 60/60 tests passed`, with `api_exercise: every public facade method was called` and `smoke: every checked value matched` |
| **consumer program** | `zig build run` in `consumer/` | Debug / native, linked | **0** | `local://foundation-contract-erfa-consumer-linked-run.log` — `Build Summary: 7/7 steps succeeded`, `consumer: every checked value matched` |
| **upstream validation programs** | `zig build upstream-test` | Debug / native, linked | **0** | `local://foundation-contract-erfa-linked-single-output-corrected-smoke-and-full-facade-test.log` — `t_erfa_c validation successful`, `t_erfa_c_extra validation successful`, `upstream-test success`. The same run's `test` step did not compile, so this row is evidence for `upstream-test` alone |
| **`-Dlinkage=dynamic` install** | `zig build install -Dlinkage=dynamic -Druntime=false -j2 --summary all --prefix …/erfa-shared` | Debug / native | **0** | `local://foundation-contract-erfa-native-shared-unused-foreign-refusal-graph-fixed-build.log` — `Build Summary: 19/19 steps succeeded`, `install success` |
| **runtime-loaded smoke against a supplied provider** | `zig build smoke -Druntime=true -Dlinkage=static -j2 --summary all --prefix …/erfa-runtime-static -- --provider …/erfa-shared/lib/liberfa.so.1.8.1` | Debug / native | **0** | `local://foundation-contract-erfa-current-canonical-real-runtime-static-smoke-after-leap-table-invariant-fix.log` — `Build Summary: 7/7 steps succeeded`, `smoke: loaded provider …`, `smoke: every checked value matched` |
| **all recorded upstream bytes** | `sha256sum -c` over the recorded upstream paths | n/a | **0** | `local://foundation-contract-erfa-all-recorded-native-upstream-bytes-integrity.log` — 268 lines, every line `: OK`, none failing |
| **runtime-loaded suite + facade exercise + smoke** | `zig build smoke test -Druntime=true -Dlinkage=static -Doptimize=ReleaseSafe -j2 --summary all`, `ERFA_TEST_PROVIDER` naming `…/erfa-shared/lib/liberfa.so.1.8.1` | ReleaseSafe / native, runtime-loaded | **1** | `local://foundation-resumed-erfa-loaded-static-ReleaseSafe.json` — `Build Summary: 10/12 steps succeeded (1 failed); 60/60 tests passed`, `smoke success`, and `run exe erfa-exercise failure` with `process terminated with signal ABRT` at `api_exercise.zig:738`, an `Illegal instruction` `@trap()` in the `s2xpv` dispatch stub. The defect this found is §3e; **this row is the finding, not a clearance** |

**What the current rows cover and what they do not.** The 12-step row is the
whole of the typed route exercised natively in one configuration: 60 behavioural
tests, the facade exercise that calls every public wrapper, and the smoke
example, all against the linked static build with `.use_llvm` set. The consumer
row is a second program, not a repeat of the first. **The only row that is not
`Debug` against the 197-member surface is red.** The runtime-loaded
`ReleaseSafe` row runs the same `test` step and gets `60/60`, then aborts in the
facade exercise at `vectors.s2xpv` (§3e) — it is the finding, not a clearance.
`ReleaseSafe`, `ReleaseFast` and `ReleaseSmall` were unobserved for this surface
when these rows were taken; **§9a.3 is what moved them**, and it is the current
evidence. §9a.2 keeps the `60/60` counts because they are what its own receipts
print; the suite now stands at 61 tests.

**No row in §9a.2 is a 53-platform matrix**, and the §9a one predates this wave.
**The runtime-loaded configuration's own test suite had been run once when these
rows were taken, and that run failed**; the other runtime row was a `Debug` smoke
program against one provider named by absolute path. §9a.3 supplies both: a
53-cell matrix and four runtime/linkage combinations. What remains pending is
named per row in §9a.3 and not here.

**Two facts about the shared object, read out of the installed file rather than
from a gate.** The artefact `-Dlinkage=dynamic` installed is
`lib/liberfa.so.1.8.1` with `lib/liberfa.so` → `lib/liberfa.so.1` →
`lib/liberfa.so.1.8.1` beside it, and `readelf -d` on it reports
`SONAME liberfa.so.1` and `NEEDED libm.so.6`. `nm -D --defined-only` on the same
file reports **255** defined symbols, all of them `T era*`, and no other defined
symbol at all — which is the count of declarations in the four headers, so the
shared delivery carries the whole `era*` surface this package describes. That is
an inspection of one file on one host; it says nothing about a Windows `DEF`
export list, which no gate has exercised.

**What the four mode rows do and do not say.** Each is a single run on the
native target, and they differ in which steps they were asked for. `Debug` is
the only one that carried `install` and `upstream-test` together. `ReleaseSafe`
carried `upstream-test` without `install`. `ReleaseFast` and `ReleaseSmall`
were asked for `test smoke consumer`, and `test` is the step that runs both the
51 tests and the facade exercise (`run test 51 pass (51 total)` and
`run exe erfa-exercise success` appear under it), so the exercise is green in
all four modes. The two upstream validation programs are green in `Debug` and
in `ReleaseSafe`; they were not invoked in the other two, and no
`ReleaseFast`/`ReleaseSmall` upstream result is claimed. `.use_llvm = true` is
set on every Zig root in `build.zig` and in `consumer/build.zig` regardless of
mode, so these four rows are evidence that the flag holds in every mode — not
that the default backend is also correct in any of them.

The summary records no optimize mode. `cross-test.profile.sh` is settings-only
and sets no `-Doptimize`, and the harness runs `zig build test -Dtarget=TARGET`
per target, so the build is the toolchain default — **Debug** — and the summary
does not independently confirm that. Treat the mode as read from the profile,
not from the receipt.

### 9a.3 Observed on the current graph — the source-bound cohort

Four driver gates ran against the graph as it now stands, after §3e's correction.
The 53-cell cohort is the source-bound one: its receipt records
`source_stamp_before == source_stamp_after` (`a4ed8e98…`) with
`zig_version 0.16.0`, `mode zig-build`, `target_count 53`, `target_jobs 8` and
`jobs_per_build 8`.

| Gate | Command | Optimize / target | Exit | Evidence |
|---|---|---|---:|---|
| **native eight cells, linked** | `zig build test smoke install -Doptimize=<mode> -Dlinkage=<l> -Druntime=false -j8 --summary all` | Debug, ReleaseSafe, ReleaseFast, ReleaseSmall × static, dynamic / native | **0** in all eight | `native-final-evidence/20261004T233628757747Z-69351/run.json` — `Build Summary: 25/25 steps succeeded; 61/61 tests passed` |
| **own-loaded eight cells** | the same eight configurations with `-Druntime=true` and `ERFA_TEST_PROVIDER` naming this tree's own `liberfa.so.1.8.1` (`provider.kind: "own"`) | the same eight / native | **0** in all eight | `loaded-final-evidence/20261004T232823091897Z-23133/run.json` — `Build Summary: 26/26 steps succeeded; 61/61 tests passed` |
| **53-platform `cross-test`** | `cross-test --jobs 8 --build-jobs 8` from the package root | toolchain default (`Debug`, per `cross-test.profile.sh`) / 53 targets | **0**, `status: partial` | `20261004T221720228710Z-45046/erfa-53-target-8.json` — `pass 20, fail 0, build_only 33, partial 0`, every executed cell `tests=61` |
| **compile-only six-target `check` baseline** | `zig build check -j8 --summary all` | default / six triples | **0** | `baselines-and-configs/20261005T014547Z-797a73f2`, row `baseline-erfa-check` — `Build Summary: 55/55 steps succeeded`, `declared_target_count 6`, all six named, `test_pass_lines: []`, `refusal_log_lines: 0` |

**What these rows settle.** All four optimize modes, both linkages, and the
runtime-loaded shape of each, at `61/61` on the corrected surface — including the
`vectors.s2xpv` path §3e repaired, which is inside that count. The 53-cell matrix
exists, and it is green over the twenty cells it can execute.

**What they do not settle.**

* **`build_only` is not a pass.** Thirty-three of the 53 cells compiled and ran
  nothing because no executor was available, and that set includes all nine
  NetBSD targets and `wasm32-wasi`. They are compile evidence, and §3.4's NetBSD
  and `wasm32-wasi` boundaries stand unchanged.
* **The `check` baseline runs nothing.** `test_pass_lines` is empty and the
  receipt's own `runtime_pass_claimed` is `false`; it derives no runtime result
  under any exit code.
* **`upstream-test` and `consumer` are not in the eight cells.** Those are
  `test smoke install`, so the §9a.2 receipts remain the evidence for the two
  upstream validation programs and for the consumer program.
* **`-Druntime=true` did not carry `consumer` or `upstream-test`**, and no
  option-on/option-off diff was taken.
* **The loader's own consumer-behaviour rows** — explicit path vs named-system
  source, no fallback, atomic publication, explicit retry after failure,
  idempotence, rejection of a changed request after READY, pre-initialization
  panic in ReleaseFast and ReleaseSmall — remain unexercised, as `README.md` §3.3
  says.
* **The Windows `DEF` export list** remains unexercised, and the `nm`/`readelf`
  facts above remain an inspection of one file on one host.
* **Both Nix derivations, the devenv routes, the moved-tree `pkg-config` check,
  `check -Dlinkage=dynamic` and the installed-C consumer linked and run against
  `lib/liberfa.so`** are untouched by these receipts.

**The bound on the cohort.** Its source identity is its own epoch and nothing
later: an edit to this graph, its helpers or its generated headers that landed
after `20261004T221720228710Z-45046` is not covered by any count above.

**The installed-C result is about the install, not the facade.** The program
is the **same C source the workflow's installed-C job carries** — taken
verbatim from that job's heredoc and compiled and run unchanged by the driver,
outside CI, against the install this tree produces. It `#include`s **all four**
installed headers — `erfa.h`, `erfam.h`, `erfaextra.h` *and* `erfadatextra.h`,
the last of which no other public header pulls in — and checks real values:
`eraCal2jd(2017,1,1)` returning `0` with `djm0 == ERFA_DJM0` and
`djm == 57754.0`, `eraDat(2017,1,1,0.0)` returning `0` with ΔAT in (36.9, 37.1),
`eraVersionMajor() >= 2`, and `ERFA_DAYSEC == 86400.0`. Every one of those is a
value from the installed archive or the installed macros, so a missing header,
a missing macro or a stale archive fails to compile, fails to link, or fails at
run time. It says nothing about the Zig facade, and nothing about
`eraApco13`'s status (it is a C program; see §1a). It was taken against the
install produced by the `Debug` row above, with no separate `install` run of its
own. Sharing the workflow's program is not the same as having run the workflow;
§9c keeps those apart.

**The 53-platform result, in full and without rounding.** 53 targets, run id
`20261003-194646-57707-28197`, `zig_version 0.16.0`, `mode zig-build`,
`bookkeeping_failure false`, `target_count 53`, overall `status: partial`,
`exit_code 0`, with `counts: pass 20, fail 0, build_only 33, partial 0`:

- **20 runtime passes**, every one of them reporting `tests: 51` with
  `reason: tests_complete` — including `x86_64-linux` and `aarch64-linux`.
- **0 failures.** No target is `build_failed`.
- **33 `build_only`**, each `build: pass` with `run: unavailable` and
  `reason: runtime_unavailable`. A successful foreign compile is **not** a
  passing test, and an unavailable runner is never a pass. `wasm32-wasi` is one
  of them: it builds, and nothing ran it. **All nine NetBSD targets are in that
  33** — `aarch64-netbsd`, `aarch64_be-netbsd`, `arm-netbsd`, `armeb-netbsd`,
  `mips-netbsd`, `mipsel-netbsd`, `powerpc-netbsd`, `x86-netbsd` and
  `x86_64-netbsd` each report `build: pass` / `run: unavailable` /
  `reason: runtime_unavailable`. None of them is a failure any more, and none
  of them has ever been *run*.

`status: partial` is this harness's own word for "not every platform had a
runner". It is not a failure, and the run's own `exit_code` is `0`.

**What the 53 run does not cover.** Its target names are the published
Tier 1/2 spellings — `x86_64-linux`, `aarch64-macos`, `wasm32-wasi` — not the
workspace's six `-Dtarget` triples (`x86_64-linux-gnu`, `aarch64-linux-gnu`,
`aarch64-macos-none`, `x86_64-windows-gnu`, `riscv64-linux-gnu`,
`wasm32-wasi`). `aarch64-macos` is **not** `aarch64-macos-none`, and the
libc-less target is absent from that table entirely. The six-target `check` is
the gate that covers those six spellings, including the libc-less one, and it
has its own receipt above; the two runs are complementary and neither stands
in for the other.

**Superseded runs, kept as history.** These are real receipts. None of them is
current state, and none may be cited as a result:

- `local://foundation-matrix-erfa-r2-native-install` (record only; its log was
  not retained) — `zig build -j2 -Doptimize=Debug --summary all --prefix
  …/erfa/install`, exit 0. Superseded by the `Debug` row above, which ran the
  same `install` step together with the rest.
- `local://foundation-matrix-erfa-before-complete-runtime.log` — Debug, native,
  exit 1, `38/51 tests passed (13 failed)`, the consumer not compiling and the
  facade exercise failing. That is the state the corrections in `CHANGELOG.md`
  entry 8 landed against.
- `local://foundation-matrix-erfa-semantic-r4.log` — `zig build test smoke
  consumer upstream-test`, Debug, native, exit 1, red on **one** transcribed
  value in the facade exercise (`expected 0.8921045614537038, got
  0.8921006945555556`) with `51/51 tests passed`, smoke green, consumer green,
  and `upstream-test success` with both programs printing `validation
  successful`.
- `local://foundation-matrix-erfa-semantic-r5.log` — `zig build test smoke
  consumer`, Debug, native, exit 0, `Build Summary: 15/15 steps succeeded;
  51/51 tests passed`, with `run exe erfa-exercise success`, `smoke success`
  and `consumer success`, and each of the three programs' own last line —
  `api_exercise: every public facade method was called`, `consumer: every
  checked value matched`, `smoke: every checked value matched`. Those three
  lines are the programs' self-checks, not this package's word for them. It
  ran neither `install` nor `upstream-test`.
- `local://foundation-matrix-erfa-installed-c-compile-r0.log` /
  `-run-r0.log` — the first installed-C pair, taken against an earlier install.
  The `-current` pair above re-takes the same check against the install this
  tree produces.
- `local://foundation-matrix-erfa-cross-original-summary.json` — the
  pre-NetBSD-route 53-platform run, run id `20261003-182240-52530-15219`,
  `status: fail`, `exit_code 1`, `counts: pass 20, fail 9, build_only 24,
  partial 0`. **All nine of its failures are NetBSD**, `reason: build_failed`,
  five errors at `math.h:607`, C archive compiled. It is the record of the cause
  §4 describes and of nothing else; the corrected run above is current.
- `local://foundation-matrix-erfa-netbsd-preprocess-check.log` (exit 2) and
  `-r1.log` (exit 1, `Build Summary: 7/11 steps succeeded (3 failed)`) — the
  two `aarch64-netbsd` checks that failed before the translation route and
  before the 128-bit typedef bridge respectively. The second one's failure is
  quoted in §4.
- The contract wave of 2026-10-04, 04:20–05:44, kept as the record of how the
  extended surface got here. Each is a real receipt and every one is red:
  `…-linked-native-identity-precondition-fixed-full-api-test.log` is
  `58/60 tests passed` with `matrices: a rotation is undone by its transpose` and
  `spherical: a unit direction decomposes back to its two angles` failing — the
  rotation row on `matrices.rotateX` called without the identity seed, and the
  spherical row on an expectation that `eraC2s` normalises `theta`, which it does
  not (§3d). `…-native-refraction-sign-and-matrix-angle-oracles-fixed-full-test-recovered-output.log`
  is `60/60 tests passed` with the facade exercise red on the `pvu` position at
  `1e-14`. `…-full-exercise-real-vector-component-and-angle-contract-repair.log`
  is `60/60 tests passed` with the exercise red on
  `pvxpv(pv, pv).velocity[0] == 0.0`, which is the assertion §3d shows is not
  sound. The 05:44 receipt is the first current-surface pass and is in §9a.2.
- `local://foundation-contract-erfa-complete-native-shared-provider-build.log`
  (03:54) — `-Dlinkage=dynamic` aborted in the `check` walk with the refusal
  text naming `windows`. That is a superseded refusal: `build.zig` now gives
  Windows its own pass in `target_carries_shared_object`, and the shared install
  in §9a.2 is the run that followed.

### 9b. Boundaries and out-of-tree results

**The filtered-fetch consumer package is recorded outside this repository.**
The package round trip — filtered tarball, cached fetch of this package as a
dependency, and the consumer built and run from the fetched copy — is driven
and recorded separately, in
`local://foundation-matrix-final-package-proof.json`. That record is the only
thing that can establish a pass for it, and nothing in this file asserts one:
no `.erfa` package fingerprint, no `.erfa_consumer` fingerprint, no packaged
file set, no packaged digest and no downstream build are claimed here. This
row is deliberately neutral about the outcome — it names where the evidence
lives, not a state the SDK has not been told. Every row in §9a, by contrast, is
a result of this tree and names its own receipt.

Three further boundaries, stated so they are not re-read as pending work:

- **No whole-workflow execution by the driver.** `.github/workflows/verify.yml`
  exists and names these gates; the driver has not executed it, and no CI
  result is claimed from it in either direction. Every row in §9a is a direct
  `zig` or `sha256sum` invocation whose receipt is named. The one row that
  reuses workflow material is the installed-C program, and §9c says exactly how
  far that reuse goes.
- **No linter gate.** No linter was run for this package. `zig fmt` over the
  nine fork Zig/ZON files is the only formatter result claimed, and a
  formatter exit 0 is not a build result.
- **No release-asset digest.** The pin was archived from the checkout
  (`git archive --format=tar 1a8044c…`, whole-stream SHA-256
  `5137fc806f882a6ff70acaa0b91819d3d3a8db34f99366c8472eff6cc99280a8`, receipt
  `local://foundation-project-matrix-source-pins.json`) and its 269 per-file
  digests matched `UPSTREAM.sha256` exactly — same membership, same digests,
  zero mismatches. That is an archive of the pinned git tree, not a release
  asset; no `erfa-2.0.1.tar.xz` digest exists for this pin and none is claimed.

### 9c. Three things the receipt list will not tell you

- **`zig build` does not install the executables.** `b.getInstallStep()
  .dependOn(&exe.step)` is a `Compile.step` dependency: the default step
  *compiles* the smoke example and the facade exercise and installs neither.
  What `zig build` installs is `liberfa.a`, the four public headers, `LICENSE`
  and `INFO` (the `b.installArtifact` / `b.installFile` calls in `build.zig`'s
  default step). "Compiled" and "installed" are different
  claims and this package keeps them apart.
- **A cross-target compile is `build_only`.** `.github/workflows/verify.yml`
  names these gates and adds an installed-C consumer job; a successful foreign
  compile is not a passing test, and an unavailable runner is never a pass.

**The installed-C program is the workflow's own program; the workflow itself
was not run.** The source compiled and run in §9a was taken verbatim from the
installed-C job's heredoc in `.github/workflows/verify.yml` and used unchanged,
so the driver run and that job check the same C: all four public headers —
`erfadatextra.h` included, which no other header pulls in — and real values
rather than only an echoed macro, so a missing install fails the check instead
of passing it. **What has not happened is the workflow.** The driver did not
execute `verify.yml`; it invoked one C program and `zig` directly, outside CI,
against the install this tree produces
(`local://foundation-matrix-erfa-installed-c-current-compile.log` /
`-run.log`). Reusing the workflow's source is not the same as producing a CI
result, and nothing here asserts one: no CI run, runner, scheduling or outcome
is claimed for this package, in either direction.