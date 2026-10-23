# ERFA notices

| Paths | Licence and attribution |
|---|---|
| `LICENSE` | Upstream BSD-3-Clause terms, including the SOFA derivation preamble, acknowledgement request and no-endorsement term; NumFOCUS Foundation. |
| `INFO` | IAU SOFA Board permission for NumFOCUS relicensing, subject to the `era` function prefix and no Board copyright; provenance, not a licence. |
| `src/*.c`, `src/*.h` (255 files) | Upstream BSD-3-Clause; NumFOCUS Foundation. 250 files carry the SOFA-derived notice; four declare that they are not SOFA-derived and refer to `LICENSE`; `src/t_erfa_c_extra.c` carries both notices. |
| Upstream root files without in-file notices: `README.rst`, `RELEASE.rst`, `bootstrap.sh`, `configure.ac`, `Makefile.am`, `meson.build`, `src/Makefile.am`, `src/meson.build`, `m4/erfa-numver.m4`, `erfa.pc.in` | Upstream BSD-3-Clause under `LICENSE`, unmodified. |
| `.gitignore` | Upstream material under `LICENSE`; modified by this fork and the only modified upstream file. |
| `README.upstream.md` | Copy of upstream `README.rst`; upstream BSD-3-Clause. |
| Fork-authored files listed below | BSD-3-Clause by direct authorization from the package owner, under `FORK-LICENSE.md`; not covered by upstream's grant. No individual copyright holder is named. |

Fork-authored files:

- `build.zig`, `build.zig.zon`
- `zig/translate.h`, `zig/root.zig`, `zig/api_exercise.zig`, `tests.zig`, `smoke.zig`
- `runtime/library.zig`, `runtime/graph.zig`, `runtime/loader.zig`, `runtime/generate.zig`, `runtime/sync.c`, `runtime/sync.h`
- `consumer/build.zig`, `consumer/build.zig.zon`, `consumer/src/main.zig`, `cross-test.profile.sh`
- `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml`, `.envrc`
- `README.md`, `README.zig.md`, `FORK-LICENSE.md`, `FORK-NOTES.md`, `CHANGELOG.md`, `NOTICE.md`, `UPSTREAM.md`, `UPSTREAM.sha256`

The three `IAU ERFA Board` references in `src/ae2hd.c`, `src/hd2ae.c` and `src/hd2pa.c` are routine documentation, not copyright grants. No SOFA endorsement is claimed.

Third-party source and data: none. This per-file inventory is not a legal opinion.
