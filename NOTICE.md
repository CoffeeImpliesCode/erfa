# NOTICE.md — per-file licence record for the ERFA package

`foundation-libs/AGENTS.md` §2 vocabulary. Everything here is `SOURCE-CONFIRMED`
by reading the files named. **No licence gate, scan tool or build was run; these
are reads, and the counts are mechanical counts over the tree, not estimates.**

The rule this file exists to enforce: a package carries material licensed by
each file's own terms, not by the licence of its most prominent file, and a
fork-authored file is licensed by **this fork's own grant**, not by anything
upstream granted. The grant, its SPDX identifier and the owner's authorization
are in `FORK-LICENSE.md`; §4 lists every file it covers.

## 1. Root terms

| Path | What it is | Term |
|---|---|---|
| `LICENSE` | BSD-3-Clause terms with the SOFA derivation preamble, the "unaltered state" note for the SOFA original (`LICENSE:11-15`), the acknowledgement request (`LICENSE:22-23`), and clause 3's no-endorsement term (`LICENSE:38-41`). Retained byte-for-byte. | BSD-3-Clause, upstream |
| `INFO` | The IAU SOFA Board's relicensing permission, quoted from Catherine, Chair, IAU SOFA Board (`INFO:4-9`). Retained byte-for-byte. | **Not a licence.** Provenance and relicensing authority. |

`INFO` is the authority for the two relicensing conditions, both of which this
package's material satisfies and neither of which this package re-grants or
extends: every function name carries the `era` prefix in place of `iau`, and the
SOFA Board is not a copyright holder of the ERFA files (the in-file copyright
lines name NumFOCUS Foundation; the three "IAU ERFA Board" lines named in §3
are in-document notes about the routine, not copyright grants).

**No SOFA endorsement is claimed or implied.** Clause 3 (`LICENSE:38-41`) bars
using the names of the Standards of Fundamental Astronomy Board, the IAU or its
contributors to endorse or promote products derived from the software without
prior written permission. Nothing in this package does that, and no upstream
statement is presented as an approval of this package.

## 2. `src/` — measured per-file classification

255 files exist in `src/`: 251 `.c` (249 core + 2 test programs) and 4 `.h`.
Every one was classified by reading its own text. Three classes, mechanically
counted:

| Class | Count | What the file carries |
|---|---:|---|
| A. SOFA-derived | 250 | A derivation statement ("This library is derived, with permission, from the International Astronomical Union's 'Standards of Fundamental Astronomy' library"), the `Copyright (C) 2013-2023, NumFOCUS Foundation.` line, the full BSD-3 terms **inline**, and clause 3 |
| B. Declared NOT derived | 4 | "This file is NOT derived from SOFA sources", "Licensed under a 3-clause BSD style license - see LICENSE", and **no** inline BSD text and **no** clause 3 |
| C. Both | 1 | `src/t_erfa_c_extra.c` — the class-B header *and* a class-A footer |

Measured cross-check: the clause-3 text is present in exactly 251 of the 255
files, and the 4 without it are exactly the 4 class-B files.

**Every one of the 255 files is BSD-3-Clause in terms.** The classes differ in
*attribution and self-description*, not in term, so there is no licence conflict
in the tree. The classes are itemised because a single flat label would state
something the files themselves do not.

### 2a. Class B — the four files that declare they are not derived from SOFA

| Path | Header notice | Measured lines |
|---|---|---|
| `src/erfaextra.h` | `Copyright (C) 2016-2019, NumFOCUS Foundation.` / `Licensed under a 3-clause BSD style license - see LICENSE` / `This file is NOT derived from SOFA sources.` | `erfaextra.h:2,4,6` |
| `src/erfadatextra.h` | `Copyright (C) 2019, NumFOCUS Foundation.` / BSD by reference / `This file is NOT derived from SOFA sources.` | `erfadatextra.h:2,4,6` |
| `src/erfaversion.c` | `Copyright (C) 2016-2017, NumFOCUS Foundation.` / BSD by reference / `This file is NOT derived from SOFA sources` (no trailing period in this file) | `erfaversion.c:2,4,6` |
| `src/erfadatextra.c` | `Copyright (C) 2019, NumFOCUS Foundation.` / BSD by reference / `This file is NOT derived from SOFA sources.` | `erfadatextra.c:2,4,6` |

Their contents are consistent with that claim as far as reading them shows:
version accessors reading `config.h`, and the leap-second table accessor pair
plus the internal initialiser. `src/erfadatextra.h:20-21` and
`src/erfadatextra.c:15-16,74-75` state that `eraDatini` is an implementation
detail of `dat.c` and "should not be used elsewhere"; it is nevertheless
exported with a public declaration at `src/erfadatextra.h:23`.

### 2b. Class C — the one inconsistent attribution, recorded not repaired

`src/t_erfa_c_extra.c` states at `t_erfa_c_extra.c:6` that the file is NOT
derived from SOFA sources, and at `t_erfa_c_extra.c:2-4` that it is BSD-3 by
reference. It then ends with a full SOFA-derivation BSD-3 footer that includes:

- `t_erfa_c_extra.c:123` — `Copyright (C) 2013-2023, NumFOCUS Foundation.`
- `t_erfa_c_extra.c:126-128` — the "derived, with permission, from the
  International Astronomical Union's …" statement
- `t_erfa_c_extra.c:163-166` — the clause-3 no-endorsement term
- `t_erfa_c_extra.c:168-179` — the warranty disclaimer

**Why it is recorded and not fixed:** both texts are BSD-3-Clause, so no
obligation is unsatisfied and no redistribution right is affected; the
inconsistency is in the file's self-description. Repairing it would mean editing
an upstream byte, which this package does not do. The upstream test program is
shipped unchanged for that reason.

### 2c. Copyright-line census, all 505 in-file copyright lines

| Occurrences | Line text |
|---:|---|
| 497 | `Copyright (C) 2013-2023, NumFOCUS Foundation.` |
| 3 | `Copyright (C) 2023 IAU ERFA Board. See notes at end.` |
| 3 | `Copyright (C) 2019, NumFOCUS Foundation.` |
| 1 | `Copyright (C) 2016-2017, NumFOCUS Foundation.` |
| 1 | `Copyright (C) 2016-2019, NumFOCUS Foundation.` |

The three "IAU ERFA Board" lines are in the routine doc block of three files —
`src/ae2hd.c:64`, `src/hd2ae.c:64`, `src/hd2pa.c:51` — each of which *also*
carries the standard `Copyright (C) 2013-2023, NumFOCUS Foundation.` line and
the class-A footer. They are named here so that a per-file audit does not have
to rediscover them; they are not a separate term and not a second copyright
holder for redistribution purposes.

## 3. Root-level files that carry no in-file licence statement

`README.rst`, `RELEASE.rst`, `.gitignore`, `bootstrap.sh`, `configure.ac`,
`Makefile.am`, `meson.build`, `src/Makefile.am`, `src/meson.build`,
`m4/erfa-numver.m4`, `erfa.pc.in` and `.github/workflows/ci_workflows.yml` carry
**no** copyright or licence notice in their own text. They are redistributed
under the package's BSD-3-Clause terms (`LICENSE`), unmodified.

### 3a. `README.upstream.md` is upstream material, not a fork file

`README.upstream.md` is a **byte-for-byte copy of upstream's `README.rst` at the
pin**, preserved separately so that the fork README at `README.md` does not
replace or mislabel it. Its SHA-256 is
`c70af9a82e6258eb0712acf61498929c69e7d6d2beba4682b11a15fc8a3ceefd`, the same
digest `UPSTREAM.sha256` records for `README.rst` (`UPSTREAM.sha256:60`); the
driver extracted and byte-verified it, receipt
`local://foundation-contract-upstream-readme-proof.json`, entry `erfa`.

It is therefore **upstream material under upstream's BSD-3-Clause terms**, not a
fork-authored file, and §4 does not list it. `README.rst` itself stays in the
tree as upstream material and stays digested; the two paths carry the same bytes
and this copy is not a rename.

## 4. This fork's own files — BSD-3-Clause by owner authorization

The following are authored by this fork and are **not** covered by the grants in
`LICENSE`, which name the NumFOCUS Foundation as copyright holder. They are
licensed `BSD-3-Clause` by direct authorization from the owner of this package
(SPDX `BSD-3-Clause`); see `FORK-LICENSE.md` for the authorization and the full
text. No individual holder is named, because none is known to this record.

- `build.zig`, `build.zig.zon`
- `zig/translate.h`, `zig/root.zig`, `zig/api_exercise.zig`, `tests.zig`,
  `smoke.zig`
- `runtime/library.zig`, `runtime/graph.zig` — the route's SDK-specific half.
  `runtime/library.zig` carries `SPDX-License-Identifier: BSD-3-Clause` at line 1,
  the identifier this section grants; `runtime/graph.zig` carries no header and
  should. The reusable core `graph.zig` names — `runtime/loader.zig`
  (`graph.zig:205`), `runtime/sync.c` (`graph.zig:265`), `runtime/generate.zig`
  (`graph.zig:291`) and `runtime/sync.h` — is copied in unchanged from the
  driver's reviewed pilot and takes the same term.
- `consumer/build.zig`, `consumer/build.zig.zon`, `consumer/src/main.zig`
- `cross-test.profile.sh`
- `.github/workflows/verify.yml`
- `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml`, `.envrc`
- `README.md`, `FORK-LICENSE.md`
- `UPSTREAM.md`, `UPSTREAM.sha256`, `NOTICE.md`, `README.zig.md`,
  `FORK-NOTES.md`, `CHANGELOG.md`

Earlier revisions of this section said "no licence asserted" for these paths;
that described the state before the authorization and is superseded by the grant
above. `README.upstream.md` is deliberately absent from this list — see §3a.
Files this fork authors later take the same grant and are added here as they
land. Nothing in it asserts SOFA derivation or SOFA endorsement.

### The one carried upstream file this fork edits

| File | Change |
|---|---|
| `.gitignore` | Upstream's ignore list — `/aclocal.m4`, `/autom4te.cache/`, `/config.*`, `/configure`, `/depcomp`, `/erfa.pc`, `/install-sh`, `/libtool`, `/ltmain.sh`, `/m4/`, `/missing`, `/stamp-h?`, `/test-driver`, `.deps/`, `.dirstamp`, `.libs/`, `*.l[ao]`, `*.o`, `*~`, `Makefile`, `Makefile.in`, `/build-aux`, `src/t_erfa_c`, `erfa-*.tar.gz` — is kept **verbatim and in its original order**; all 24 patterns are present and none was removed, reordered relative to another, or weakened. The fork appends `!/m4/` and `!/m4/erfa-numver.m4`, because upstream's `/m4/` would otherwise swallow `m4/erfa-numver.m4`, which is upstream **source** that this package ships, lists in `.paths` and digests; and then `/.zig-cache/`, `/zig-out/`, `/zig-pkg/` plus the three `consumer/`-anchored equivalents. No fork source or record matches any pattern. Because the file is therefore not byte-identical to upstream's, it is **deliberately absent from `UPSTREAM.sha256`** and from the unmodified-paths diff in `verify.yml`, and the append is recorded here instead. Upstream digest `e84d726d8ebf4331d491995ff5ff0a49a64f0b8740e29d21191d307eb05e793d`; as shipped by this fork `7804ec5be7cbf3051e6bea43fcca210e02edbb110242a0eca574c01132b340ee`. |

No other upstream file is touched. In particular **no `.c` and no `.h` file is
patched**, which is what the native-byte check exists to confirm.

## 5. Third-party material

**None.** This package bundles no third-party source, no vendored data set and
no generated table from another project. There is no `testdata/` directory,
because upstream ships no fixture files: the two test programs are
self-contained C with no external input.

The upstream oracle's *expected values* are a provenance fact, not a licence
fact: `src/t_erfa_c.c` is the validation suite inherited from SOFA, and its
expected values and tolerances come from that reference suite (README.rst:52-59
records the relationship between ERFA and SOFA test-for-test). It carries its
own class-A BSD-3 footer and is shipped unmodified under the same terms as the
rest of `src/`.

If a fixture with independent terms is ever added — for example reference
values transcribed from IERS bulletins or the *Explanatory Supplement to the
Astronomical Almanac* — it must land with its own recorded provenance and its
own terms in this file, and be listed in `UPSTREAM.sha256` under the same
manifest as the material it accompanies. Nothing in this wave needs one, and
none has been invented.

## 6. Scope

This is a per-file inventory of the material in this tree. It is not a legal
opinion and it is not a licence audit run by tooling; the driver's integrity
and native-byte checks, when it runs them, are what would confirm the digests in
`UPSTREAM.sha256` against the shipped bytes.