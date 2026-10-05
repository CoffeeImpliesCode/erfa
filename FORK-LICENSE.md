# FORK-LICENSE.md — the licence of this fork's own files

Covers only the files this fork authored. Upstream's material keeps its own
terms in `LICENSE` and `INFO`; both are retained byte-for-byte and both are
installed by the build.

## 1. Authorization

Direct authorization from the owner of this package, recorded in
`foundation-libs/AGENTS.md` §8: the owner chose a per-project licence for
fork-authored additions, matching each project's primary upstream terms where
appropriate, and directed that the authorization and the resulting grant be
recorded here and in `NOTICE.md`. Earlier revisions of this package that say
"no licence asserted" describe the state before that authorization.

## 2. Grant

| | |
|---|---|
| SPDX identifier | `BSD-3-Clause` |
| Applies to | every path in `NOTICE.md` §4 |
| Copyright holder | the owner of this fork, who granted it |
| Basis | the authorization in §1 |

ERFA's own term is BSD-3-Clause (`LICENSE`), so a downstream that already
accepts upstream's terms accepts these files on the same ones.

**Copyright line.** No individual is named, because none is known to this record
and inventing one would be a fabrication. Where a tool requires a line rather
than a holder:

```
Copyright (c) 2026, the ERFA package owner and contributors.
```

**SPDX header** for newly authored source and build files:

```
SPDX-License-Identifier: BSD-3-Clause
```

Upstream files do not get that header; they carry their own notices, unchanged.

## 3. Terms

```text
BSD 3-Clause License

Copyright (c) 2026, the ERFA package owner and contributors.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors
   may be used to endorse or promote products derived from this software
   without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

This is plain BSD-3-Clause and matches `LICENSE` as a term. It is not
`LICENSE`: `LICENSE` additionally carries the SOFA derivation preamble, the
"unaltered state" note (`LICENSE:11-15`) and the acknowledgement request
(`LICENSE:22-23`), and names the NumFOCUS Foundation as copyright holder. Those
are upstream's statements about upstream's files. Nothing in this grant asserts
SOFA derivation or SOFA endorsement, and `INFO`'s two relicensing conditions —
the `iau` → `era` prefix change and the removal of the SOFA Board as a copyright
holder — bind upstream's files.

## 4. Which set a file belongs to

| Set | Term | Record |
|---|---|---|
| The 268 pinned upstream files digested in `UPSTREAM.sha256`, plus `.gitignore` as the recorded deviation | BSD-3-Clause with the SOFA derivation preamble; 250 of the `src/` files carry it, four declare themselves not derived from SOFA and one test file declares that and then carries the SOFA-derivation footer anyway. All 255 files under `src/` are BSD-3-Clause in terms; the classes differ in self-description, not in term. | `LICENSE`, `INFO`, `NOTICE.md` §1–§3 |
| Every file this fork authored, listed path by path | BSD-3-Clause, §2–§3 | `NOTICE.md` §4 |
| `README.upstream.md` | **Upstream material.** A byte-for-byte copy of upstream's `README.rst` at the pin, `sha256 c70af9a82e6258eb0712acf61498929c69e7d6d2beba4682b11a15fc8a3ceefd`, the digest `UPSTREAM.sha256:60` records for `README.rst`. Extracted and byte-verified by the driver; receipt `local://foundation-contract-upstream-readme-proof.json`, entry `erfa`. `README.rst` itself stays in the tree, byte-identical and digested; the copy is not a rename. | `UPSTREAM.md` §2, `NOTICE.md` §3a |

The integrity gate is `sha256sum -c UPSTREAM.sha256`: 268 files, every line OK
at the run recorded in `README.zig.md` §9a. A flake or package that installs
these records needs `NOTICE.md`, `FORK-LICENSE.md`, `UPSTREAM.md`,
`README.upstream.md` and `README.rst` inside `.paths`, which is what
`verify.yml` checks.
