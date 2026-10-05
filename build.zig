//! Build for the `erfa` package: the canonical Essential Routines for
//! Fundamental Astronomy C library, compiled from this repository, and a Zig
//! facade published on top of it.
//!
//! Upstream pin: liberfa/erfa master `1a8044cde5b7763295d472a6443387239127c6c8`
//! (v2.0.1 tag `9915ba38c9365f8b0738269b8c2ac1fdd5f8dee3` is its ancestor).
//! SOFA base 20231011; the package's own version literals still read 2.0.1.
//!
//! `zig build --help` lists the steps. They are:
//!
//!   zig build              build the C library and compile the smoke example
//!                          and the facade exercise
//!   zig build test         run the behavioural tests and the facade exercise
//!   zig build smoke        run the smoke example
//!   zig build upstream-test run upstream's own two validation programs
//!   zig build check        compile everything for the six required cross
//!                          targets, running nothing
//!
//!   cross-test            the same `test` step, over the full published
//!                          53-platform Zig 0.16.0 Tier 1/2 table rather than
//!                          the host alone. `cross-test` discovers
//!                          `cross-test.profile.sh` from this package root and
//!                          runs `zig build test -Dtarget=TARGET` for each
//!                          platform with a fresh cache.
//!
//! Options
//!
//!   -Doptimize=...        standard; the gates use Debug and ReleaseSafe
//!   -Dtarget=...          standard; naming a target makes `check` check that
//!                         one target instead of all six
//!
//!   -Dlinkage=static      a static archive, `liberfa.a`. This is the default
//!                         and is exactly what this graph hard-coded before
//!                         the option existed -- `addGraph` wrote
//!                         `.linkage = .static` straight into `b.addLibrary` --
//!                         so passing nothing changes nothing.
//!                         `-Dlinkage=dynamic` builds a real
//!                         shared object carrying upstream's own libtool ABI
//!                         version: `ERFA_LIB_VERSION_INFO(9, 1, 8)`
//!                         (`configure.ac:20`) with the same
//!                         `-soname: (C - A).A.R` rule `meson.build:10-20`
//!                         spells out, so `lib erfa.so.1.8.1` with the soname
//!                         `liberfa.so.1` and a `liberfa.so` link beside it.
//!                         A target whose platform cannot carry a shared
//!                         object cannot carry it at all, and
//!                         `-Dlinkage=dynamic` there is refused rather than
//!                         answered with a different artefact
//!                         (see "Linkage" below)
//!
//!   -Druntime=true        resolve the native entry points at run time instead
//!                         of linking them. The facade keeps the same
//!                         translated header, the same native types and the
//!                         same public `LoadSource`/`LoadError`; each selected
//!                         entry point becomes a dispatch through one
//!                         process-lifetime table an explicit `load(source)`
//!                         fills, and the module links no native library at
//!                         all. Independent of `-Dlinkage`, which still
//!                         decides which artefact this build delivers and
//!                         installs -- and under this option it still does:
//!                         the library is built either way, because a caller
//!                         may name a provider this tree did not build and may
//!                         equally name the one it did. Default off, and a
//!                         linked build is unchanged in every respect
//!
//! There is deliberately no `b.systemIntegrationOption`. See "No system mode"
//! below; the rule is recorded as NOT APPLICABLE for this wave rather than
//! satisfied or vacuous.
//!
//! ## What is compiled, and from where
//!
//! `core_sources` is the 249 translation units `src/Makefile.am:2-35`
//! (`liberfa_la_SOURCES`) names, in upstream's own order and upstream's own
//! line breaks, which `src/meson.build:6-39` lists identically. The two
//! validation programs `t_erfa_c.c` and `t_erfa_c_extra.c` are *not* in that
//! list -- upstream builds them as `check_PROGRAMS`
//! (`src/Makefile.am:49-52`) -- and are compiled separately by the
//! `upstream-test` step and by `check`, never folded into the library.
//!
//! Nothing is downloaded, no autotools, meson or Make step is invoked, and
//! `configure.ac`, `m4/erfa-numver.m4`, `bootstrap.sh` and `erfa.pc.in` are
//! carried as upstream source without being run.
//!
//! ## `config.h`
//!
//! Exactly one compiled file reads a generated header: `src/erfaversion.c:15-17`
//! includes `<config.h>` under `#ifdef HAVE_CONFIG_H`, and `grep` over `src/`
//! finds no other `config.h` consumer. Upstream generates it from values
//! recorded in its own build files -- `configure.ac:5` (`AC_INIT([erfa],
//! [2.0.1])`), `m4/erfa-numver.m4:22-24` (the major/minor/micro split) and
//! `configure.ac:23` / `meson.build:29` (`SOFA_VERSION`) -- and this build
//! writes the same five macros from the same recorded inputs, in the cache,
//! never in the source tree.
//!
//! The three numeric macros are derived from the one version string here
//! rather than written as three independent literals, so they cannot drift out
//! of agreement with `PACKAGE_VERSION` or with each other. Nothing else is
//! defined: upstream's generated header carries the rest of autoconf's
//! boilerplate, no file in this tree reads any of it, and defining a macro
//! nothing tests is a claim this build cannot support.
//!
//! `-DHAVE_CONFIG_H` and the generated directory go on the compilation's
//! include path *and* on the translation's, so the two lines resolve the same
//! names. No public header reads any of the five macros -- they reach the
//! *functions* in `erfaversion.c`, not a declaration -- so the translation is
//! unaffected by them today; putting the directory on that line anyway means a
//! future upstream header that did read one would find this build's value
//! rather than whatever `config.h` a build machine happens to have.
//!
//! ## Which front end reads `zig/translate.h`
//!
//! `zig translate-c` parses C with Aro, and Aro preprocesses as well as parses,
//! so the aggregate header can be read either way round: Aro can do both jobs,
//! or the target's own C preprocessor can do the first and Aro the second.
//! `aggregateRoute` decides per target and `preprocessedAggregate` is the
//! extra front end. Both routes read this repository's four public headers on
//! the same include path with the same macros; only the preprocessor that has
//! to understand the target's C library changes.
//!
//! Every target but NetBSD keeps the route it already had. `erfa.h:15` reaches
//! one system header and no other -- `math.h`, written in the quoted form that
//! falls back to the include path because this tree has no `src/math.h` -- and
//! every other C library in this matrix spells `__END_DECLS` as plain tokens
//! that Aro parses.
//!
//! NetBSD's does not. `generic-netbsd/sys/cdefs.h:431-432` routes `__END_DECLS`
//! through `__BEGIN/END_PUBLIC_DECLS`, which `:411-416` defines as `extern "C"`
//! framing around `_Pragma("GCC visibility push(default)")` and
//! `_Pragma("GCC visibility pop")`. `<math.h>` closes every declaration block
//! with `__END_DECLS`, so every NetBSD translation drags two `_Pragma`
//! operator invocations into the translation, and Aro destringizes each into a
//! `#pragma` line it then hands to the parser as C. The observed full-matrix
//! run reported five errors at `math.h:607` for that reason on all nine
//! NetBSD targets and on no other target, with the C archive itself compiled.
//! Those targets take the extra front end; nothing else about them changes.
//!
//! That front end runs the compiler that is compiling the C core, for the
//! target the core is compiled for, on the include path and with the generated
//! `config.h` the core is compiled with. So the declarations the translator
//! reads are the ones the archive answers to, rather than a second revision of
//! them.
//!
//! What that extra front end also has to carry is the compiler's own
//! `__int128_t`. `generic-netbsd/arm/cdefs.h:62-63` spells `__ALIGNBYTES`
//! through that name under `__ARM_PCS_AAPCS64`, which is itself one of the
//! compiler's predefines for AArch64; `-dD` keeps the spelling, and no header
//! declares the typedef, because Clang declares it next to the `__int128`
//! primitive it provides. So the preprocessed text names an identifier nothing
//! in it declares -- `pub const __ALIGNBYTES = __helpers.sizeof(__int128_t) -
//! @as(c_int, 1);` -- and the translation fails with `use of undeclared
//! identifier '__int128_t'`
//! (`local://foundation-matrix-erfa-netbsd-preprocess-check-r1.log:3-6`).
//! `zig/translate.h` restates `__int128_t` and `__uint128_t` ahead of the four
//! includes, under the compiler's own `__SIZEOF_INT128__`, which Clang defines
//! exactly when the target has that type. Both routes read the declaration and
//! no target without the extension is given one; `zig/translate.h`'s own
//! comment carries the rest. Nothing else about either route changes.
//!
//! ## The C dialect is not pinned
//!
//! Upstream names no `-std`: `meson.build:1-5` declares `project('erfa', 'c',
//! version: '2.0.1')` with no `c_std`, and `configure.ac:12` is a bare
//! `AC_PROG_CC` with no `AC_PROG_CC_C99` or `AC_PROG_CC_STDC`.
//!
//! That is not an omission to fix here, because the dialect decides which
//! branch of the `ERFA_THREAD_LOCAL` chain is taken. `src/erfadatextra.h:38-50`
//! selects `thread_local` for C23, `_Thread_local` for C11 and later, then
//! `__declspec(thread)` for MSVC, then `__thread` for GCC and Clang, then the
//! empty definition. Which of those applies on `wasm32-wasi` is an open
//! question for the driver's gate to answer from a real compile, not something
//! this file should decide by pinning a dialect or by defining
//! `ERFA_THREAD_LOCAL` itself. The native sources are used exactly as upstream
//! ships them.
//!
//! The risk this build deliberately carries, stated here so it is not
//! discovered by surprise. `src/erfadatextra.c:22-23` holds the leap-second
//! table's active state as `static ERFA_THREAD_LOCAL eraLEAPSECOND *changes`
//! and `static ERFA_THREAD_LOCAL int NDAT = -1`, and that is precisely the
//! change master `1a8044cd` made over the v2.0.1 tag: at the tag both were
//! plain `static`, a process-global data race in any threaded host. The chain
//! has five outcomes, and one of them is the empty definition, selected when
//! a target defines neither C++11, nor `__STDC_VERSION__ >= 201112L`, nor
//! `_MSC_VER`, nor `__GNUC__`/`__clang__`. A target that lands there silently
//! becomes process-global again -- the bug the pin exists to fix -- and it
//! would compile and run without a diagnostic. That is a finding a gate must
//! report, not one this file may pre-empt: no `-std=` is added and
//! `ERFA_THREAD_LOCAL` is not defined here, so the answer is whatever the
//! compiler's own default dialect produces for each target.
//!
//! If a gate shows a target rejecting the selected spelling, or landing on the
//! empty branch, the fix belongs in build configuration that selects one of
//! the *existing* upstream branches -- a `-std=` or an `ERFA_THREAD_LOCAL`
//! define, both recorded as a build deviation with the target and the
//! reasoning. It does not belong in a native edit, and it must not be made
//! silently.
//!
//! ## What this package registers, and what it installs
//!
//! One module is registered, `erfa`: `zig/root.zig`, with the translation of
//! `zig/translate.h` bound to the module name `c` and re-exported by the
//! facade. `dep.module("erfa")` is the whole of what a dependent needs --
//! `module.linkLibrary(c_lib)` carries the compiled archive, so importing the
//! module and nothing else links the library. The translated header is
//! imported rather than registered: `dep.module("c")` would hand a dependent
//! the same declarations with nothing behind them. `createModule` is what the
//! six cross-target graphs use, because a module registered by name against
//! the whole build would leave only the last of six reachable.
//!
//! `b.installArtifact(c_lib)` installs `liberfa.a` -- or, under
//! `-Dlinkage=dynamic`, the shared object with its soname and version links --
//! together with the four headers upstream installs (`src/Makefile.am:37`,
//! `src/meson.build:46`): `erfa.h`, `erfam.h`, `erfaextra.h` and
//! `erfadatextra.h`, flat and under their own names, so a C consumer writes
//! `#include <erfa.h>` and `-lerfa`. `installHeader` puts that include
//! directory on the search path of anything that links the artefact, so a
//! dependent needs nothing from this repository to call the C API.
//!
//! `addPkgConfig` installs `lib/pkgconfig/erfa.pc`, rendered here from
//! upstream's own `erfa.pc.in` fields, and `installRecords` installs the
//! carried licence and provenance material under `share/licenses/erfa/` and
//! upstream's documentation under `share/doc/erfa/`. Both are the build
//! graph's to own: an install layout described in two places is two answers
//! to one question.
//!
//! ## Linkage: `-Dlinkage=static|dynamic`
//!
//! Two options, one default, and the default is the only change-free one.
//! Before this option existed `addGraph` wrote `.linkage = .static` into
//! `b.addLibrary` directly, and every recorded gate in this repository's
//! history observed that artefact. So `static` is the default, and
//! `-Dlinkage=static` is a no-op rather than a change: the `pic` field
//! `addGraph` sets is `?bool`, and `null` emits no flag at all, where `false`
//! would add `-fno-PIC` to a command line that has never carried it.
//!
//! `dynamic` changes the artefact's *kind* and nothing else about the
//! compilation: the same 249 translation units, the same generated
//! `config.h`, the same four headers, the same translation, the same facade,
//! the same tests, the same smoke example and the same two upstream validation
//! programs. No source is compiled out for a shared object and no header is
//! substituted for it.
//!
//! What the shared object needs that the archive does not is its own: PIC on
//! every object (so `pic = true` on the one module all 249 units share),
//! upstream's ABI version, and an export surface.
//!
//! ### The version is upstream's, not a number invented here
//!
//! `configure.ac:20` records `ERFA_LIB_VERSION_INFO(9, 1, 8)` and
//! `src/Makefile.am:45` passes it to libtool as `-version-info`;
//! `meson.build:10-20` reproduces the same triple as `libtool_version` and
//! documents the derivation it stands for, `--soname: (C - A).A.R`, giving
//! `soversion = '1.8.1'`. So the shared object is `liberfa.so.1.8.1` with the
//! soname `liberfa.so.1` and a `liberfa.so` beside it, which is what
//! `b.addLibrary`'s `.version` produces through
//! `std/Build/Step/Compile.zig:491-505` and `:1824-1834`. `.version` is null
//! for a static archive, which has no soname and no versioned file name.
//!
//! ### The export surface is the headers', and there is nothing to add to it
//!
//! ERFA declares no export or visibility macro anywhere. `src/erfa.h`,
//! `src/erfam.h`, `src/erfaextra.h` and `src/erfadatextra.h` carry plain
//! `extern` declarations, two `extern "C"` blocks and 255 function prototypes
//! between them, and no `__declspec`, no `__attribute__((visibility))`, no
//! `ERFA_API`. Upstream's own builds say the same thing by omission:
//! `src/Makefile.am` and `src/meson.build` set no visibility preset, no
//! version script and no export list, so libtool's shared `liberfa.so` exports
//! every default-visibility symbol the core defines.
//!
//! That makes this library the easy case rather than the hard one, and the
//! build follows it: no `-fvisibility=hidden`, no version script and no
//! hand-written export list, because any of those would *narrow* a surface
//! upstream leaves open, and a second list beside the header could only drift
//! from it. The 255 entry points are the header's; every symbol the core
//! defines is one of them, plus the two file-scope `static
//! ERFA_THREAD_LOCAL` leap-second variables of `src/erfadatextra.c:22-23`,
//! which have internal linkage and are in no symbol table at all.
//!
//! On Windows this means a MinGW DLL is built from the same sources with the
//! same declarations, and it is the linker's default-export behaviour that
//! decides what the import library offers -- a fact a gate reports from the
//! produced `.dll.a`, not one this file pre-judges. ERFA ships no
//! import/export macro pair to switch, so there is none to split; that is a
//! difference from `blake3`, which has `BLAKE3_DLL`/`BLAKE3_DLL_EXPORTS` in
//! `c/blake3.h:9-14` precisely so it can, and its build defines them on
//! opposite sides of the same library.
//!
//! ### A target that cannot carry a shared object refuses the request
//!
//! `std.Target.DynamicLinker.kind` answers from the OS tag alone: WASI is
//! `.none` (`lib/std/Target.zig:2385`), and `zig build check` walks a
//! `wasm32-wasi` target. A `.so` there is a file nothing can load, so there is
//! no shared object to build for it. `-Dlinkage=dynamic` on that target
//! therefore stops at configure time with the target named, rather than
//! handing back a static archive: a caller who asked for a shared object did
//! not get one, and a printed line saying so afterwards does not make the
//! artefact match the request. The default delivery is unaffected -- an
//! archive is buildable everywhere, so `-Dlinkage=static` on `wasm32-wasi` is
//! an ordinary build and the six-target `check` covers it like the other five.
//!
//! `addGraph` resolves the request through `resolved_linkage` for both the
//! artefact and the declarations paired with it, so the two cannot describe
//! different linkages.
//!
//! ### Which targets cannot carry one is two facts, not one
//!
//! `target_carries_shared_object` treats a Windows target as able to carry a
//! shared object even though `std.Target.DynamicLinker.kind` answers `.none`
//! for it (`lib/std/Target.zig:2380`). A PE/COFF image has no interpreter path
//! and no PT_INTERP segment at all: its imports are resolved by the loader
//! inside the OS, and the shared object is an input to that loader rather
//! than something an interpreter names. The absence of an ELF interpreter is
//! therefore not the same fact as the absence of a shared object. Reading it
//! as one fact would refuse `-Dlinkage=dynamic` on this package's own
//! `x86_64-windows-gnu` matrix cell, the one cell here that produces
//! `liberfa.dll` plus its import library. WASI gets no such pass: a `.wasm`
//! module has no dynamic linker and no OS loader to resolve its imports, so a
//! shared object there is still a file nothing can load.
//!
//! ### Immediate for a named target, a failing step for a row nobody named
//!
//! `zig build -Dtarget=wasm32-wasi -Dlinkage=dynamic` is refused in the
//! published graph before any step runs, which is what `resolved_linkage` is
//! for. Inside `zig build check -Dlinkage=dynamic` the WASI row is one the
//! caller did not name, so it becomes an explicit `addFail` step carrying the
//! same reason while the other five rows are still compiled. Nothing at all is
//! built for that row and it is not dropped either, so it cannot pass by
//! omission; and because `check` is not a dependency of the install step, a
//! native `zig build install` is never poisoned by a target it never compiles.
//!
//! ## What the translation reaches, and where the provider seam goes
//!
//! The aggregate header `zig/translate.h` includes is the four installed
//! headers and nothing else. Of those, `erfa.h:15` reaches one system header,
//! `"math.h"`, and the other three reach none; `erfadatextra.h:14` includes
//! `erfaextra.h`, which is already in the set. So the whole C-library surface
//! the translation sees is `math.h`'s declarations -- the libc noise a
//! generated dispatch has to keep direct -- plus 255 ERFA entry points:
//! 247 in `erfa.h`, 7 in `erfaextra.h`, 1 in `erfadatextra.h`, all functions,
//! no data symbols, no callback types, and no entry point that is
//! configuration-dependent or optional. `erfam.h` declares no function at
//! all; it is macros, which is why `-dD` matters on the preprocessing route.
//! All 255 are defined by the 249 core units, and the core's only other
//! file-scope objects are the two `static ERFA_THREAD_LOCAL` leap-second
//! variables of `src/erfadatextra.c:22-23`, which have internal linkage and
//! are in no symbol table at all.
//!
//! ### `-Druntime`, and the seam that carries it
//!
//! `-Druntime` selects the *dispatch*, and it is orthogonal to `-Dlinkage`:
//! this option says which artefact the build delivers and installs, that one
//! says whether the facade calls it through a link line or through a table an
//! explicit `load(source)` fills. Under it the library is still built and
//! installed -- a caller may name the provider this tree did build, or one it
//! did not -- but nothing is linked into the module, because the symbols are
//! meant to arrive through the platform loader.
//!
//! The whole seam is in `addGraph`, and it is three lines:
//!
//!   * the `c` import becomes `graph.createModule(b, translate, target,
//!     optimize)` instead of `translate.createModule()`. The dispatch keeps
//!     this translation's exact native type and constant namespace, routes
//!     each selected entry point through the table, and leaves libc noise
//!     direct. It is generated from the real translation output for the target
//!     and configuration being built, so it describes the headers this build
//!     selected, and it does not compile a second copy of the native extern
//!     structs that then had to be cast between nominally distinct modules.
//!   * `module.linkLibrary(c_lib)` goes away entirely in that branch. Not for
//!     this tree's own library and not for an installed one: linking either
//!     would make the linker demand every entry point before `load` is ever
//!     called, and the route would silently be a linked one.
//!   * the linked branch adds `module.addImport("rt",
//!     graph.createCoreModule(b, target, optimize))`, because it has no
//!     dispatch and `LoadSource`/`LoadError` -- this SDK's public types -- come
//!     from the core. A provider branch must not import it separately:
//!     `createModule` makes the one core instance the dispatch uses and
//!     re-exports those two types from it, and a second instance would be a
//!     second, nominally distinct `LoadSource` that `erfa.load` could not
//!     accept.
//!
//! `runtime/graph.zig` and `runtime/library.zig` are the API role's files; this
//! build calls them and defines nothing of the route itself. Its
//! synchronization prefix is `erfa_rt`, so its `runtime/sync.c` symbols cannot
//! collide with another SDK's.
//!
//! This route is independent of the package's *system* mode, which stays NOT
//! APPLICABLE for a separate reason recorded below: that rule is about
//! compiling and translating against a *build-time* installed library, while
//! this is about resolving a provider at *run* time, with the source pin and
//! the translated ABI unchanged either way.
//!
//! ## No system mode
//!
//! This package offers no system-library mode, and that is recorded as NOT
//! APPLICABLE rather than as a satisfied or a vacuous rule: this wave's
//! contract fixes the source pin and the bounded contracts to be identical in
//! every mode, and declares that a fork with no system mode documents the rule
//! as not applicable instead of claiming a system gate.
//!
//! Independently, no installed `liberfa` could serve this package's published
//! surface: upstream's own install rules publish the same four headers, but
//! the leap-second state this package exists to ship -- the thread-local
//! `eraLEAPSECOND *changes` in `src/erfadatextra.c`, added after the v2.0.1
//! tag -- is in no released `liberfa` binary, and every packaged 2.0.1 carries
//! the process-global table instead. Translating this tree's headers against
//! such a library is exactly the "bundled header newer than the installed ABI"
//! failure the workspace rule forbids.
//!
//! ## How `check` proves the facade
//!
//! Zig analyses a function body only when something calls it, so compiling a C
//! archive proves nothing about the facade, and reflecting over the module
//! proves nothing either. `check` therefore compiles, for each of the six
//! targets and running nothing: `zig/api_exercise.zig`, `tests.zig`,
//! `smoke.zig` and both of upstream's validation programs. Every public
//! declaration in `zig/root.zig` must be called from one of the first three,
//! or `check` stops covering it; namespacing is not a call. A passing `check`
//! is compile evidence, never a claim that a foreign binary ran.

const std = @import("std");

/// The provider route's build half, authored by the API role.
///
/// `createModule` builds the generated dispatch that replaces
/// `translate.createModule()` under `-Druntime`, and what it returns is
/// imported as the module's `c` import. Nothing it builds links this tree's
/// native library: in that configuration the symbols arrive through the
/// platform loader when a caller names a provider with an explicit
/// `load(source)`. `createCoreModule` builds the same core for the *linked*
/// branch, where there is no dispatch and the facade's `rt` import is where
/// `LoadSource` and `LoadError` come from.
///
/// The two branches must not both call `createCoreModule`. Those two names are
/// this SDK's public types and have to be the *same* types in one build: a
/// second core instance would be a second, nominally distinct `LoadSource`,
/// and `erfa.load(source)` would be handing the facade's type to a function
/// expecting the dispatch's. `addGraph` holds the branch and is the only
/// caller of either.
const runtime_graph = @import("runtime/graph.zig");

/// The name of the compiled artifact, the registered module, and the `-l`
/// name a C consumer of the installed tree uses. Upstream's own library name
/// (`src/Makefile.am:1`, `lib_LTLIBRARIES = liberfa.la`) and package name are
/// both ERFA, and this contract fixes the published identity as `erfa`.
const lib_name = "erfa";

/// `configure.ac:5` (`AC_INIT([erfa],[2.0.1])`) and `meson.build:3`
/// (`version: '2.0.1'`). This is the value upstream's own `eraVersion`
/// returns and the value its generated `config.h` carries.
const package_version = "2.0.1";

/// `configure.ac:23` (`AC_DEFINE([SOFA_VERSION], ["20231011"], ...)`) and
/// `meson.build:29` (`confdata.set_quoted('SOFA_VERSION', '20231011')`).
const sofa_version = "20231011";

/// The shared object's ABI version, in libtool's `current:revision:age` form
/// and in the `major.minor.patch` shape `b.addLibrary`'s `.version` takes.
///
/// `configure.ac:20` records `ERFA_LIB_VERSION_INFO(9, 1, 8)` and
/// `src/Makefile.am:45` passes it to libtool as `-version-info`;
/// `meson.build:10-20` names the same triple `libtool_version = [9, 1, 8]`,
/// states the derivation it stands for -- "libtool: C:R:A / -soname: (C - A).A.R"
/// -- and computes `soversion = '1.8.1'` from it. So the two build systems
/// upstream ships agree on `lib erfa.so.1.8.1` with the soname
/// `liberfa.so.1`, and that is what this constant carries.
///
/// `major` is the soname number: it is `C - A = 9 - 8 = 1`, and it is the only
/// part a consumer's `DT_NEEDED` records or a `.system` load has to name.
const abi_version: std.SemanticVersion = .{ .major = 1, .minor = 8, .patch = 1 };

/// The complete compiled core: the 249 files of `liberfa_la_SOURCES` in
/// `src/Makefile.am:2-35`, in upstream's order and on upstream's own line
/// breaks, which `src/meson.build:6-39` reproduces file for file.
///
/// Nothing is generated, selected or skipped: every core routine upstream
/// ships is compiled on every target. Upstream's two validation programs are
/// deliberately absent, because upstream builds them as `check_PROGRAMS`
/// (`src/Makefile.am:49-52`) and not as library sources.
const core_sources = [_][]const u8{
    "src/a2af.c",         "src/a2tf.c",   "src/ab.c",     "src/ae2hd.c",  "src/af2a.c",   "src/anp.c",    "src/anpm.c",   "src/apcg13.c",
    "src/apcg.c",         "src/apci13.c", "src/apci.c",   "src/apco13.c", "src/apco.c",   "src/apcs13.c", "src/apcs.c",   "src/aper13.c",
    "src/aper.c",         "src/apio13.c", "src/apio.c",   "src/atcc13.c", "src/atccq.c",  "src/atci13.c", "src/atciq.c",  "src/atciqn.c",
    "src/atciqz.c",       "src/atco13.c", "src/atic13.c", "src/aticq.c",  "src/aticqn.c", "src/atio13.c", "src/atioq.c",  "src/atoc13.c",
    "src/atoi13.c",       "src/atoiq.c",  "src/bi00.c",   "src/bp00.c",   "src/bp06.c",   "src/bpn2xy.c", "src/c2i00a.c", "src/c2i00b.c",
    "src/c2i06a.c",       "src/c2ibpn.c", "src/c2ixy.c",  "src/c2ixys.c", "src/c2s.c",    "src/c2t00a.c", "src/c2t00b.c", "src/c2t06a.c",
    "src/c2tcio.c",       "src/c2teqx.c", "src/c2tpe.c",  "src/c2txy.c",  "src/cal2jd.c", "src/cp.c",     "src/cpv.c",    "src/cr.c",
    "src/d2dtf.c",        "src/d2tf.c",   "src/dat.c",    "src/dtdb.c",   "src/dtf2d.c",  "src/eceq06.c", "src/ee00a.c",  "src/ee00.c",
    "src/eect00.c",       "src/eo06a.c",  "src/epb2jd.c", "src/epj2jd.c", "src/epv00.c",  "src/eqeq94.c", "src/ecm06.c",  "src/ee00b.c",
    "src/ee06a.c",        "src/eform.c",  "src/eors.c",   "src/epb.c",    "src/epj.c",    "src/eqec06.c", "src/era00.c",  "src/fad03.c",
    "src/fae03.c",        "src/faf03.c",  "src/faju03.c", "src/fal03.c",  "src/falp03.c", "src/fama03.c", "src/fame03.c", "src/fane03.c",
    "src/faom03.c",       "src/fapa03.c", "src/fasa03.c", "src/faur03.c", "src/fave03.c", "src/fk425.c",  "src/fk45z.c",  "src/fk524.c",
    "src/fk54z.c",        "src/fk52h.c",  "src/fk5hip.c", "src/fk5hz.c",  "src/fw2m.c",   "src/fw2xy.c",  "src/g2icrs.c", "src/gc2gd.c",
    "src/gc2gde.c",       "src/gd2gc.c",  "src/gd2gce.c", "src/gmst00.c", "src/gmst06.c", "src/gmst82.c", "src/gst00a.c", "src/gst00b.c",
    "src/gst06a.c",       "src/gst06.c",  "src/gst94.c",  "src/hd2ae.c",  "src/hd2pa.c",  "src/h2fk5.c",  "src/hfk5z.c",  "src/icrs2g.c",
    "src/ir.c",           "src/jd2cal.c", "src/jdcalf.c", "src/ld.c",     "src/ldn.c",    "src/ldsun.c",  "src/lteceq.c", "src/ltecm.c",
    "src/lteqec.c",       "src/ltpb.c",   "src/ltp.c",    "src/ltpecl.c", "src/ltpequ.c", "src/moon98.c", "src/num00a.c", "src/num00b.c",
    "src/num06a.c",       "src/numat.c",  "src/nut00a.c", "src/nut00b.c", "src/nut06a.c", "src/nut80.c",  "src/nutm80.c", "src/obl06.c",
    "src/obl80.c",        "src/p06e.c",   "src/p2pv.c",   "src/p2s.c",    "src/pap.c",    "src/pas.c",    "src/pb06.c",   "src/pdp.c",
    "src/pfw06.c",        "src/plan94.c", "src/pmat00.c", "src/pmat06.c", "src/pmat76.c", "src/pm.c",     "src/pmp.c",    "src/pmpx.c",
    "src/pmsafe.c",       "src/pn00a.c",  "src/pn00b.c",  "src/pn00.c",   "src/pn06a.c",  "src/pn06.c",   "src/pn.c",     "src/pnm00a.c",
    "src/pnm00b.c",       "src/pnm06a.c", "src/pnm80.c",  "src/pom00.c",  "src/ppp.c",    "src/ppsp.c",   "src/pr00.c",   "src/prec76.c",
    "src/pv2p.c",         "src/pv2s.c",   "src/pvdpv.c",  "src/pvm.c",    "src/pvmpv.c",  "src/pvppv.c",  "src/pvstar.c", "src/pvtob.c",
    "src/pvu.c",          "src/pvup.c",   "src/pvxpv.c",  "src/pxp.c",    "src/refco.c",  "src/rm2v.c",   "src/rv2m.c",   "src/rx.c",
    "src/rxp.c",          "src/rxpv.c",   "src/rxr.c",    "src/ry.c",     "src/rz.c",     "src/s00a.c",   "src/s00b.c",   "src/s00.c",
    "src/s06a.c",         "src/s06.c",    "src/s2c.c",    "src/s2p.c",    "src/s2pv.c",   "src/s2xpv.c",  "src/sepp.c",   "src/seps.c",
    "src/sp00.c",         "src/starpm.c", "src/starpv.c", "src/sxp.c",    "src/sxpv.c",   "src/taitt.c",  "src/taiut1.c", "src/taiutc.c",
    "src/tcbtdb.c",       "src/tcgtt.c",  "src/tdbtcb.c", "src/tdbtt.c",  "src/tf2a.c",   "src/tf2d.c",   "src/tpors.c",  "src/tporv.c",
    "src/tpsts.c",        "src/tpstv.c",  "src/tpxes.c",  "src/tpxev.c",  "src/tr.c",     "src/trxp.c",   "src/trxpv.c",  "src/tttai.c",
    "src/tttcg.c",        "src/tttdb.c",  "src/ttut1.c",  "src/ut1tai.c", "src/ut1tt.c",  "src/ut1utc.c", "src/utctai.c", "src/utcut1.c",
    "src/xy06.c",         "src/xys00a.c", "src/xys00b.c", "src/xys06a.c", "src/zp.c",     "src/zpv.c",    "src/zr.c",     "src/erfaversion.c",
    "src/erfadatextra.c",
};

/// The four headers upstream installs, named flat at their own paths:
/// `include_HEADERS` in `src/Makefile.am:37` and `install_headers` in
/// `src/meson.build:46`. Both name the same four and no others, and neither
/// puts them in a subdirectory of the include root, so neither does this.
const public_headers = [_][]const u8{
    "erfa.h",
    "erfam.h",
    "erfaextra.h",
    "erfadatextra.h",
};

/// The licence and provenance material `zig build` installs under
/// `share/licenses/erfa/`.
///
/// `LICENSE` is upstream's own grant -- the BSD-3-Clause text with the SOFA
/// derivation preamble -- and `INFO` is the IAU SOFA Board's relicensing
/// permission, which is the *authority* for the grant rather than a licence.
/// Both are upstream files and both are required: a downstream that ships only
/// one of them has removed an obligation, which a private repository does not
/// do. `NOTICE.md`, `FORK-LICENSE.md` and `UPSTREAM.md` are this fork's own
/// records and travel with the binaries they describe.
///
/// The order is `NOTICE.md`'s: upstream's texts first, then the records that
/// describe what this fork did to them.
const licence_records = [_][]const u8{
    "LICENSE",
    "INFO",
    "NOTICE.md",
    "FORK-LICENSE.md",
    "UPSTREAM.md",
};

/// Upstream's documentation that ships with the installed tree, under
/// `share/doc/erfa/`.
///
/// `README.rst` is upstream's file, kept byte-for-byte; `README.upstream.md`
/// is this fork's preserved copy of that same file, kept separately so a
/// reader can tell upstream's words from this fork's. Neither is a build
/// input.
const doc_records = [_][]const u8{
    "README.upstream.md",
    "README.rst",
};

/// Upstream's own validation programs, as `src/Makefile.am:49-52` builds them
/// (`TESTS`, `check_PROGRAMS`, one `SOURCES` line each) and as
/// `src/meson.build:48-51` builds them (two `executable(...)`/`test(...)`
/// entries). Both are self-contained: they open no fixture, read no data file
/// and need no environment, which is why they can be the fork's native oracle
/// unchanged.
///
/// `name` is upstream's program name and the artefact name here, so a failing
/// run names the program that failed. `source` is upstream's file, compiled
/// as upstream compiles it.
const upstream_validation_programs = [_]struct { name: []const u8, source: []const u8 }{
    .{ .name = "t_erfa_c", .source = "src/t_erfa_c.c" },
    .{ .name = "t_erfa_c_extra", .source = "src/t_erfa_c_extra.c" },
};

/// The facade root, reached by a dependent as `dep.module("erfa")`.
const facade_source = "zig/root.zig";

/// The aggregate header this build translates. It is the route to all four
/// public headers and adds no ERFA declaration of its own; what it does
/// declare is the compiler's own `__int128_t` and `__uint128_t`, under the
/// compiler's own `__SIZEOF_INT128__`. See "Which front end reads
/// `zig/translate.h`" above.
const translate_header = "zig/translate.h";

/// The test root. It names the behavioural test blocks and calls the parts of
/// the public surface those blocks exercise.
const test_root = "tests.zig";

/// The smoke example: a runnable program that prints results and compares
/// them against independent expected answers.
const smoke_root = "smoke.zig";

/// The facade exercise: a compiled root that calls every public declaration of
/// the facade, which is what makes `check` a check of the facade rather than
/// of an unreferenced archive. It is compiled for all six targets and run
/// natively by `test`.
const exercise_root = "zig/api_exercise.zig";

/// The six targets `check` compiles for, and the target set the workspace
/// fixes for every package in this wave. Nothing here is pre-judged: if a
/// target turns out to need something this build does not provide, that is
/// for the gate to report, not for this file to work around.
const check_targets = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .macos, .abi = .none },
    .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    .{ .cpu_arch = .riscv64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .wasm32, .os_tag = .wasi },
};

/// One target's C library and published facade.
const Graph = struct {
    /// The compiled C library: the artefact a C consumer links and the one
    /// the facade module carries, so a dependent gets it by asking for the
    /// module alone.
    c_lib: *std.Build.Step.Compile,
    /// The facade, with `c` bound to the translated `zig/translate.h`.
    module: *std.Build.Module,
    /// The linkage this graph's artefact was built with, which is the
    /// requested one: `resolved_linkage` refuses an undeliverable request
    /// rather than changing it.
    linkage: std.builtin.LinkMode,
    /// Whether this graph's module reaches the library through a provider
    /// table rather than through `linkLibrary`. The library is built and
    /// installed either way; only the module's own linkage differs.
    runtime_loaded: bool,
};

/// Everything that consumes one target's `Graph`, so a caller can depend on
/// the builds themselves (`check`, which runs nothing) or on runs of them
/// (`test`, `smoke` and `upstream-test`, which do).
const Programs = struct {
    /// The behaviour suite, `tests.zig`.
    tests: *std.Build.Step.Compile,
    /// The facade exercise, `zig/api_exercise.zig`, whose `main` calls every
    /// public declaration.
    exercise: *std.Build.Step.Compile,
    /// The smoke example, `smoke.zig`.
    smoke: *std.Build.Step.Compile,
    /// Upstream's own two validation programs, in `upstream_validation_programs`
    /// order.
    upstream: [upstream_validation_programs.len]*std.Build.Step.Compile,
};

/// Whether the caller named a target on the command line.
///
/// `standardTargetOptions` cannot answer this: it folds `-Dtarget=X` and "no
/// `-Dtarget` at all" into the same resolved value, so comparing the query
/// against the host would report a host-native cross target as "not
/// selected" and check all six when the caller asked for one. The raw option
/// table can, because `standardTargetOptionsQueryOnly` registers the `target`
/// option by exactly this name and every `-Dname=value` the user passed is a
/// key in it.
fn target_was_named(b: *const std.Build) bool {
    return b.user_input_options.contains("target");
}

/// Whether this target can carry a shared object at all.
///
/// For most OSes that is exactly what `std.Target.DynamicLinker.kind` answers
/// from the OS tag alone (`lib/std/Target.zig:2345-2402`): `.arch_os` and
/// `.arch_os_abi` have one, `.none` does not. WASI is `.none` (`:2385`), and
/// `check_targets` walks a `wasm32-wasi` target.
///
/// Windows is the one `.none` that does carry a shared object. `.windows` is
/// `.none` (`:2380`) because a PE/COFF image has no interpreter path -- its
/// imports are resolved by the loader inside the OS -- not because Windows
/// cannot load a DLL. The two facts are read separately here rather than
/// collapsed into one predicate, because collapsing them refuses
/// `-Dlinkage=dynamic` on the `x86_64-windows-gnu` cell of this package's own
/// matrix.
///
/// WASI is deliberately not given that pass: a `.wasm` module has no dynamic
/// linker and no loader that resolves its imports at load time.
fn target_carries_shared_object(target: std.Build.ResolvedTarget) bool {
    if (target.result.os.tag == .windows) return true;
    return std.Target.DynamicLinker.kind(target.result.os.tag) != .none;
}

/// Why `-Dlinkage=dynamic` cannot be delivered for this target, or `null` when
/// it can.
///
/// A refusal and not a substitution, and there is no third answer. A caller who
/// asked for a shared object either gets one or gets this text naming the
/// target that cannot carry it.
///
/// The text is deliberately unprefixed and composable, so the configure-time
/// `@panic` in `resolved_linkage` and the failing check step in
/// `addTargetCheck` cannot describe the same boundary two different ways.
fn shared_object_refusal(b: *std.Build, target: std.Build.ResolvedTarget) ?[]const u8 {
    if (target_carries_shared_object(target)) return null;
    return b.fmt(
        "-Dlinkage=dynamic was requested for {s}, whose OS has no dynamic " ++
            "linker (std.Target.DynamicLinker.kind is .none for that OS), so no " ++
            "shared object can be built or loaded for it. This build does not " ++
            "substitute a different artefact for the one that was asked for; " ++
            "build the static delivery for this target instead, which is the " ++
            "default.",
        .{@tagName(target.result.os.tag)},
    );
}

/// Checks that a requested linkage is one this target can actually deliver,
/// and returns it unchanged.
///
/// A caller who asks for `-Dlinkage=dynamic` asked for a shared object. On a
/// target whose OS has no dynamic linker there is no such thing: a `.so` there
/// is a file nothing can load, and handing back a static archive instead would
/// be returning a different artefact than the one requested, whatever any
/// printed line said about it. So this refuses, and it refuses loudly at
/// configure time with the target named.
///
/// The default is unaffected. `-Dlinkage=static` is what this graph built
/// before the option existed, an archive is deliverable everywhere including
/// `wasm32-wasi`, and the six-target `check` walks that default over all six.
/// Nothing about the static delivery changes, and no source, header,
/// translation or program is compiled out or substituted for it anywhere.
///
/// This is the single place both the artefact and the declarations paired with
/// it resolve the request, so the two cannot disagree about it.
fn resolved_linkage(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    requested: std.builtin.LinkMode,
) std.builtin.LinkMode {
    if (requested == .dynamic) {
        if (shared_object_refusal(b, target)) |reason| std.debug.panic("erfa: {s}", .{reason});
    }
    return requested;
}

/// The name a check graph gives its artefacts: the library name and the target
/// triple.
///
/// Six cross-target graphs share one build graph, so six steps all called
/// `erfa` would make `--summary all` impossible to read. Both the artefact
/// inside `addGraph` and the program names in `addPrograms` derive from this,
/// so one target's library and its programs can never be reported under
/// different names.
fn graph_prefix(b: *std.Build, target: std.Build.ResolvedTarget) []const u8 {
    const triple = target.result.zigTriple(b.allocator) catch @panic("erfa: unspellable target");
    return b.fmt("{s}-{s}", .{ lib_name, triple });
}

/// The name the delivered artefact carries, for the configure-time summary and
/// for nothing else. It is a fact about the file on disk, derived from the
/// linkage and the target's object format rather than assumed.
fn delivered_artifact_name(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    linkage: std.builtin.LinkMode,
) []const u8 {
    return switch (linkage) {
        .static => b.fmt("lib{s}.a", .{lib_name}),
        .dynamic => switch (target.result.os.tag) {
            .macos, .ios, .tvos, .watchos, .visionos => b.fmt(
                "lib{s}.{d}.{d}.{d}.dylib (link lib{s}.{d}.dylib, soname {s}.{d}.dylib)",
                .{ lib_name, abi_version.major, abi_version.minor, abi_version.patch, lib_name, abi_version.major, lib_name, abi_version.major },
            ),
            .windows => b.fmt("{s}.dll (import library {s}.lib)", .{ lib_name, lib_name }),
            else => b.fmt(
                "lib{s}.so.{d}.{d}.{d} (link lib{s}.so, soname {s}.so.{d})",
                .{ lib_name, abi_version.major, abi_version.minor, abi_version.patch, lib_name, lib_name, abi_version.major },
            ),
        },
    };
}

/// The generated `config.h` directory.
///
/// Returns the directory rather than the file, because the only consumer
/// reaches it by the bare name upstream uses: `src/erfaversion.c:16` writes
/// `#include <config.h>`. A `LazyPath` for the file alone would put a
/// directory on the include path that does not contain it.
fn addGeneratedConfig(b: *std.Build) std.Build.LazyPath {
    const files = b.addWriteFiles();
    // The major/minor/micro triple is split out of the one recorded version
    // string, reproducing `m4/erfa-numver.m4:22-24`'s rule for the
    // `PACKAGE_VERSION` upstream actually has, so the four macros cannot
    // disagree with each other.
    const parts = splitPackageVersion(package_version);
    // One buffer built with `b.fmt`: the values are runtime strings and
    // integers, so the file cannot be assembled from compile-time literals.
    _ = files.add("config.h", b.fmt(
        \\/* Generated by build.zig from upstream's recorded version inputs.
        \\ * Do not edit; it is written into the build cache, not this tree.
        \\ *
        \\ * PACKAGE_VERSION is configure.ac:5 (AC_INIT([erfa],[2.0.1])) and
        \\ * meson.build:3 (version: '2.0.1'); the major/minor/micro split
        \\ * reproduces m4/erfa-numver.m4:22-24; SOFA_VERSION is configure.ac:23
        \\ * and meson.build:29. These five macros are the whole of what
        \\ * src/erfaversion.c:15-17 reads from this header.
        \\ */
        \\#ifndef ERFA_CONFIG_H
        \\#define ERFA_CONFIG_H
        \\
        \\#define PACKAGE_VERSION "{s}"
        \\#define PACKAGE_VERSION_MAJOR {d}
        \\#define PACKAGE_VERSION_MINOR {d}
        \\#define PACKAGE_VERSION_MICRO {d}
        \\
        \\#define SOFA_VERSION "{s}"
        \\
        \\#endif /* ERFA_CONFIG_H */
        \\
    , .{ package_version, parts.major, parts.minor, parts.micro, sofa_version }));
    return files.getDirectory();
}

/// The three numeric components of a dotted upstream version.
///
/// `m4/erfa-numver.m4:9-24` splits `PACKAGE_VERSION` with a chain of `sed`
/// substitutions, then `AC_DEFINE_UNQUOTED`s the three results. That chain is
/// upstream's own text and is not run here; this is the same rule for the
/// version upstream actually ships, written so that a version this build has
/// not seen fails loudly instead of producing a wrong header.
const VersionParts = struct { major: u32, minor: u32, micro: u32 };

fn splitPackageVersion(version: []const u8) VersionParts {
    var fields = std.mem.splitScalar(u8, version, '.');
    const major_text = fields.next() orelse
        std.debug.panic("erfa: recorded package version '{s}' has no component", .{version});
    const minor_text = fields.next() orelse
        std.debug.panic("erfa: recorded package version '{s}' has fewer than three components", .{version});
    const micro_text = fields.next() orelse
        std.debug.panic("erfa: recorded package version '{s}' has fewer than three components", .{version});
    if (fields.next() != null)
        std.debug.panic("erfa: recorded package version '{s}' has more than three components", .{version});
    return .{
        .major = parseVersionComponent(major_text, version),
        .minor = parseVersionComponent(minor_text, version),
        .micro = parseVersionComponent(micro_text, version),
    };
}

fn parseVersionComponent(text: []const u8, version: []const u8) u32 {
    return std.fmt.parseInt(u32, text, 10) catch
        std.debug.panic("erfa: component '{s}' of recorded package version '{s}' is not a number", .{ text, version });
}

/// Which front end reads `zig/translate.h` for one target.
///
/// `zig translate-c` parses C with Aro, and Aro preprocesses as well as
/// parses, so the aggregate header can be read either way round: Aro can do
/// both jobs, or the target's own C preprocessor (`zig cc -E -dD`) can do the
/// first and Aro the second. Both routes read this repository's four public
/// headers, on the same include path and with the same macros; this decides
/// only which preprocessor has to understand the target's C library.
const AggregateRoute = enum {
    /// Aro preprocesses `zig/translate.h` for itself and parses what comes out
    /// of it.
    aro,
    /// The target's own C preprocessor expands `zig/translate.h` first, and
    /// Aro parses what that produced.
    preprocessed,
};

/// Chooses the front end that reads `zig/translate.h` for this target.
///
/// ## Aro, on every target but NetBSD
///
/// `erfa.h:15` reaches one system header and no other -- `math.h` -- so the
/// drag-in is small and Aro reads the rest of this matrix's C libraries
/// without help.
/// `generic-glibc/sys/cdefs.h:140-144`, `generic-freebsd/sys/cdefs.h:65-69`
/// and `generic-openbsd/sys/cdefs.h:270-271` each define `__END_DECLS` as `}`,
/// as nothing, or as `__END_EXTERN_C` -- plain tokens. Nothing about those
/// targets changes.
///
/// ## The target's own preprocessor on NetBSD
///
/// NetBSD is the one bundled family whose `__END_DECLS` is not made of plain
/// tokens, so it is the one family whose translation cannot be left to Aro.
/// The condition is the OS tag rather than a list of nine triples because the
/// whole family shares that one header and that one cause: every NetBSD target
/// that reaches it fails for the same reason, and a list would silently stop
/// covering the next architecture.
fn aggregateRoute(target: std.Build.ResolvedTarget) AggregateRoute {
    return if (target.result.os.tag == .netbsd) .preprocessed else .aro;
}

/// `zig/translate.h`, preprocessed for the target being built.
///
/// The extra front end `aggregateRoute` selects for NetBSD. What this writes
/// is the aggregate header with every `#include` resolved, every conditional
/// settled and every macro definition kept, for the target the C core is being
/// compiled for. Nothing is stubbed, narrowed, renamed or substituted.
///
/// ## Why this preprocessor may run at all
///
/// It is the compiler running this build script -- `b.graph.zig_exe` -- so the
/// target, the include path, the widths and the generated `config.h` are the
/// ones the 249 core units are compiled with.
///
/// ## Why `-dD`
///
/// Without it the expansion carries no macro definitions and `pub const c`
/// loses them. `erfam.h` is almost entirely macros, none of the four headers
/// *uses* them, and `zig/root.zig:242-246` binds `ERFA_WGS84`, `ERFA_GRS80`
/// and `ERFA_WGS72` out of the translation, so a dump of used macros only
/// would take the whole constant set with it. `-dD` keeps the `#define` lines
/// beside the expanded text, so a macro a C caller reads as a macro still
/// reaches Zig as a constant.
///
/// ## Why `-MD`
///
/// The four public headers are reached only through `#include`, and a `-I`
/// directory argument contributes nothing but its own resolved path to a run
/// step's manifest (`Run.zig:827-831` hashes `resolved_arg`, not the
/// directory's contents). So without a depfile this step's declared inputs
/// would be `zig/translate.h` and two path strings: a later revision of
/// `src/erfa.h` would be served from the run cache and the translation would
/// go on describing the previous one. `-MD` with `-MF`, through
/// `addPrefixedDepFileOutputArg`, hands the discovered headers to the build
/// system as this step's own inputs.
///
/// ## What is deliberately not on this line
///
/// No `-std=`, and no `ERFA_THREAD_LOCAL`. This step has to ask for the same
/// language the C core is compiled with, and "The C dialect is not pinned"
/// above is why that dialect is left to the compiler's own default: pinning it
/// here would decide the `ERFA_THREAD_LOCAL` branch at
/// `src/erfadatextra.h:38-50` in a file whose job is not to decide it.
fn preprocessedAggregate(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    generated: std.Build.LazyPath,
) std.Build.LazyPath {
    // `b.graph.zig_exe` is the compiler running this build script, so the
    // preprocessor is the same pinned one the C core is compiled by.
    const run = b.addSystemCommand(&[_][]const u8{ b.graph.zig_exe, "cc", "-E", "-dD" });
    run.setName("preprocess erfa translate.h");
    if (!target.query.isNative()) {
        const triple = target.query.zigTriple(b.allocator) catch @panic("erfa: unspellable target");
        run.addArg("-target");
        run.addArg(triple);
    }
    // The same include root the C compile line gives every core source, so
    // `<erfa.h>` and its three siblings resolve to this repository's files.
    run.addPrefixedDirectoryArg("-I", b.path("src"));
    // The generated `config.h` directory, for the same `<config.h>` that
    // `src/erfaversion.c:16` includes at compile time.
    run.addPrefixedDirectoryArg("-I", generated);
    // The same define as the compilation. It is kept on the translation line
    // as well; where both lines define it, they define the identical
    // object-like macro, which C allows to be repeated without a diagnostic.
    run.addArg("-DHAVE_CONFIG_H=1");
    run.addArg("-o");
    const preprocessed = run.addOutputFileArg("erfa-translate.c");
    run.addArg("-MD");
    _ = run.addPrefixedDepFileOutputArg("-MF", "erfa-translate.d");
    run.addFileArg(b.path(translate_header));
    return preprocessed;
}

/// What one target's graph is built from. The published graph and the six
/// check graphs differ only in `public`, and the linkage is resolved from
/// `requested` against the target before anything is compiled.
const GraphOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    public: bool,
    /// The artefact kind the caller asked for, checked against the target by
    /// `resolved_linkage` and unchanged by it.
    linkage: std.builtin.LinkMode,
    /// Whether the facade dispatches native calls through a provider table an
    /// explicit `load(source)` fills, rather than through this graph's link
    /// line. Independent of `linkage`: this decides how the facade reaches the
    /// library, that one decides which library the build delivers and installs.
    runtime_loaded: bool,
};

/// Builds the C library and the published facade for one target.
///
/// `options.public` selects between the package module set, which is what a
/// dependent reaches through `dep.module("erfa")`, and a private module. The
/// six cross-target graphs need the private form: modules are registered by
/// name against the whole build, so registering `erfa` once per cross target
/// would leave only the last of them reachable and silently stop checking the
/// rest.
///
/// The artefact name is derived here: the published graph publishes `erfa`,
/// and a check graph appends the target triple, because six steps all called
/// `erfa` make `--summary all` impossible to read.
///
/// `options.linkage` is the delivery the caller asked for. What it selects is
/// the artefact and nothing else about the compilation: the same sources, the
/// same macros, the same generated `config.h`, the same translation. What a
/// shared artefact adds is its own requirements -- PIC, upstream's ABI
/// version, and the export surface the headers already describe.
fn addGraph(b: *std.Build, options: GraphOptions) Graph {
    const target = options.target;
    const optimize = options.optimize;
    const public = options.public;
    const linkage = resolved_linkage(b, target, options.linkage);
    const name = if (public) lib_name else graph_prefix(b, target);
    const generated = addGeneratedConfig(b);

    const c_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        // libc, because the sources reach `<math.h>` (`erfa.h:15`),
        // `<string.h>` (`dtf2d.c`, `d2dtf.c`, for `strcmp`),
        // `<stdlib.h>` (`moon98.c`, for `abs`) and `<float.h>` (`jd2cal.c`),
        // and because `src/t_erfa_c.c:3` and `src/t_erfa_c_extra.c:9` need
        // `<stdio.h>`.
        .link_libc = true,
        // A shared object has to be relocatable, so every one of the 249
        // objects in it is compiled PIC. They all share this one module, so
        // there is no constituent that could be left behind: the omission
        // would be a link failure rather than a lost optimisation.
        //
        // The static linkage passes `null` rather than `false`. `Module.pic` is
        // a `?bool` and `appendZigProcessFlags` emits `-fPIC`, `-fno-PIC` or
        // nothing for `true`, `false` and `null` respectively, so `false`
        // would put a flag on a command line that has never carried one and
        // make the default a change rather than the no-op it has to be.
        .pic = if (linkage == .dynamic) true else null,
    });
    // `src/`, for `<erfa.h>` from the validation programs and for the quoted
    // `"erfa.h"` / `"erfam.h"` every core source uses. This is the same
    // include root upstream's own build gives them: `src/meson.build:45`
    // (`declare_dependency(... include_directories: '.')`) and
    // `src/Makefile.am:53` (`AM_CPPFLAGS = -I$(top_srcdir)`).
    c_mod.addIncludePath(b.path("src"));
    // The generated `config.h` directory, for `<config.h>` in
    // `src/erfaversion.c:16`.
    c_mod.addIncludePath(generated);
    c_mod.addCMacro("HAVE_CONFIG_H", "1");
    // libm, and only libm: `meson.build:32` (`cc.find_library('m',
    // required: false)`) and `configure.ac:26` (`AC_SEARCH_LIBS([sin], [m],
    // ...)`) agree that the mathematical library is the one external link
    // dependency, and no other system library is named by either.
    c_mod.linkSystemLibrary("m", .{});
    c_mod.addCSourceFiles(.{ .files = &core_sources });

    const c_lib = b.addLibrary(.{
        .name = name,
        // Upstream installs a libtool archive, which is a static archive for a
        // static build and a shared object for a shared one, and that is what
        // the requested `linkage` selects here. It was checked against the
        // target above, so an undeliverable request never reaches this line.
        .linkage = linkage,
        // Upstream's own ABI version, and only for a shared object: an archive
        // has no soname and none of the versioned names would mean anything.
        .version = if (linkage == .dynamic) abi_version else null,
        .root_module = c_mod,
    });
    // `installHeader` does two things: it installs the header under its own
    // name, and it puts that directory on the include search path of anything
    // that links this artefact. So a dependent gets `<erfa.h>` from the
    // artefact it already links, with nothing from this repository.
    for (public_headers) |header| {
        c_lib.installHeader(b.path(b.fmt("src/{s}", .{header})), header);
    }

    // The translation runs for the target being built, not for this machine:
    // `addTranslateC` is handed the same `target`, so every header it reaches
    // is that target's own. `src/` is the only header search path, so
    // `<erfa.h>` and the three siblings resolve to this repository's files
    // rather than to whatever happens to be installed on the build machine.
    //
    // Which front end reads the aggregate is `aggregateRoute`'s call. The two
    // routes differ in exactly one respect: the `.aro` one hands the
    // translator this repository's `zig/translate.h` to preprocess for itself,
    // and the `.preprocessed` one hands it what `zig cc -E -dD` already wrote
    // for the same target, on the same include path and with the same macros.
    const translate = b.addTranslateC(.{
        .root_source_file = switch (aggregateRoute(target)) {
            .aro => b.path(translate_header),
            .preprocessed => preprocessedAggregate(b, target, generated),
        },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    translate.addIncludePath(b.path("src"));
    // Same generated directory and same macro as the compilation, so the two
    // lines resolve the same names. On the `.preprocessed` route those names
    // were resolved before this step ran; keeping them here means a future
    // upstream header that did read one is covered on both routes.
    translate.addIncludePath(generated);
    translate.defineCMacro("HAVE_CONFIG_H", "1");

    const module = if (public)
        b.addModule(lib_name, .{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        })
    else
        b.createModule(.{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
    // Imported, never registered: `addModule("c")` would make
    // `dep.module("c")` resolve and hand a dependent the same declarations
    // with no library behind them. The facade re-exports this as `erfa.c`,
    // which is the supported way in and carries the facade's own linkage.
    //
    // Under `-Druntime` this import becomes the generated dispatch instead,
    // and that is the whole seam. The dispatch keeps this translation's exact
    // native type and constant namespace, routes each selected entry point
    // through one process-lifetime table an explicit `load(source)` fills, and
    // leaves libc noise direct. It is generated from the real translation
    // output for this target and this configuration, so it describes the
    // headers this build selected rather than another revision of them, and it
    // does not compile a second copy of the native extern structs that then
    // had to be cast between nominally distinct modules.
    module.addImport("c", if (options.runtime_loaded)
        runtime_graph.createModule(b, translate, target, optimize)
    else
        translate.createModule());
    // Transitive linking: `dep.module("erfa")` has to carry the compiled
    // library and libm, or a dependent would compile the facade against
    // declarations with nothing behind them and fail only at link time.
    //
    // It is deliberately absent under `-Druntime`. That configuration links no
    // native library into the module at all -- not this tree's own and not an
    // installed one -- because the symbols are meant to arrive through the
    // platform loader when the caller names a provider; linking the archive as
    // well would make the linker demand every entry point before `load` is ever
    // called, and the route would silently be a linked one. The library is
    // still built and installed in that configuration: a caller may name a
    // provider this tree did not build, and may equally name the one it did.
    if (!options.runtime_loaded) module.linkLibrary(c_lib);
    // The linked branch has no dispatch, so `LoadSource` and `LoadError` --
    // this SDK's public types -- come from the loader core itself. A
    // runtime-loaded build must not import it separately: `createModule` makes
    // the one core instance the dispatch uses and re-exports those two types
    // from it, and a second instance would be a second, nominally distinct
    // `LoadSource` that `erfa.load` could not accept.
    if (!options.runtime_loaded) {
        module.addImport("rt", runtime_graph.createCoreModule(b, target, optimize));
    }

    return .{
        .c_lib = c_lib,
        .module = module,
        .linkage = linkage,
        .runtime_loaded = options.runtime_loaded,
    };
}

/// Builds one upstream validation program as upstream builds it.
///
/// `src/Makefile.am:51-52` compiles each from its own source against
/// `$(top_builddir)/src/liberfa.la`, and `src/meson.build:49` links each
/// against `liberfa`. So: one source, the library this build compiled, and the
/// include root that library's own sources use. Nothing else is passed on the
/// command line, and no line of either program's source is touched.
///
/// These are C programs with a `main`, not Zig test binaries: they are run as
/// run artefacts, and they report failure through their exit status exactly as
/// upstream's `TESTS` do.
fn addUpstreamProgram(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    graph: Graph,
    name: []const u8,
    source: []const u8,
) *std.Build.Step.Compile {
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addIncludePath(b.path("src"));
    mod.linkLibrary(graph.c_lib);
    mod.addCSourceFile(.{ .file = b.path(source) });
    return b.addExecutable(.{ .name = name, .root_module = mod });
}

/// One artefact name, from an optional prefix and a base name.
///
/// The published graph passes an empty prefix, so its artefacts carry exactly
/// the names a user would type: `erfa-smoke`, and upstream's own `t_erfa_c`
/// and `t_erfa_c_extra`. A check graph passes the target triple as the prefix,
/// because six steps all called `erfa` make `--summary all` impossible to
/// read, and the two oracle names would otherwise each appear six times over.
fn artifactName(b: *std.Build, prefix: []const u8, base: []const u8) []const u8 {
    if (prefix.len == 0) return base;
    return b.fmt("{s}-{s}", .{ prefix, base });
}

/// Builds the Zig side of one target, plus upstream's validation programs.
///
/// `prefix` is `""` for the published graph and the target triple for a check
/// graph; see `artifactName`.
fn addPrograms(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    graph: Graph,
    prefix: []const u8,
) Programs {
    const facade = graph.module;

    const test_mod = b.createModule(.{
        .root_source_file = b.path(test_root),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    test_mod.addImport(lib_name, facade);
    // Zig 0.16 native Debug mispasses the wide ERFA C ABI. LLVM is required.
    const tests = b.addTest(.{ .root_module = test_mod, .use_llvm = true });

    const exercise_mod = b.createModule(.{
        .root_source_file = b.path(exercise_root),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exercise_mod.addImport(lib_name, facade);
    const exercise = b.addExecutable(.{
        .use_llvm = true,
        .name = artifactName(b, prefix, "erfa-exercise"),
        .root_module = exercise_mod,
    });

    const smoke_mod = b.createModule(.{
        .root_source_file = b.path(smoke_root),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    smoke_mod.addImport(lib_name, facade);
    const smoke = b.addExecutable(.{
        .use_llvm = true,
        .name = artifactName(b, prefix, "erfa-smoke"),
        .root_module = smoke_mod,
    });

    var upstream: [upstream_validation_programs.len]*std.Build.Step.Compile = undefined;
    for (upstream_validation_programs, 0..) |program, i| {
        upstream[i] = addUpstreamProgram(
            b,
            target,
            optimize,
            graph,
            artifactName(b, prefix, program.name),
            program.source,
        );
    }

    return .{
        .tests = tests,
        .exercise = exercise,
        .smoke = smoke,
        .upstream = upstream,
    };
}

/// Reads a checked-in file of this package at configure time.
///
/// `b.build_root.handle` is the same directory handle `b.path` resolves
/// against, and `readFileAlloc` through it is how a build script reads a source
/// input in this Zig version; `LazyPath.getPath2` is the older, deprecated
/// spelling and is not used here. The only file read this way is upstream's own
/// `erfa.pc.in`, and only so that its field names and ordering are upstream's
/// rather than a transcription of them.
fn readPackageFile(b: *std.Build, name: []const u8) []u8 {
    return b.build_root.handle.readFileAlloc(b.graph.io, name, b.allocator, .limited(1 << 20)) catch |err| {
        std.debug.panic("cannot read {s}: {s}", .{ name, @errorName(err) });
    };
}

/// Writes `lib/pkgconfig/erfa.pc` and installs it.
///
/// The template is upstream's own `erfa.pc.in` and it is *substituted*, not
/// restated: its field names, their order and its `Name:`, `Description:`,
/// `Libs:` and `Libs.private:` spellings are upstream's, and `Makefile.am:8`
/// (`pkgconfig_DATA = erfa.pc`) is upstream's own statement that this is the
/// file a consumer asks pkg-config about. `configure.ac:28-31` is what
/// configures it in upstream's build.
///
/// Every placeholder is filled from a value this build already holds:
///
///   * `@prefix@` becomes `${pcfiledir}/../..` rather than an absolute path.
///     `pkg-config` defines `pcfiledir` as the directory holding the `.pc`
///     file, which is `<prefix>/lib/pkgconfig`, so `../..` is that prefix. The
///     result is relocatable: the installed tree can be moved, staged under a
///     sysroot or dropped into a store path that was not known when this file
///     was written, and the file still describes the copy it travels with.
///   * `@exec_prefix@`, `@libdir@` and `@includedir@` are derived from it,
///     because the three move with the prefix.
///   * `@VERSION@` is `package_version`, the string `configure.ac:5` and
///     `meson.build:3` both record -- the C library's own version, which is
///     not this fork's package version, which has to carry the commit it was
///     prepared from. It is the same constant the generated `config.h` carries
///     and the same one `eraVersion()` returns, so the `.pc` file, the header
///     and the library cannot name three different releases.
///   * `@LIBS@` is `-lm` and only `-lm`. `meson.build:32`
///     (`cc.find_library('m', required: false)`) and `configure.ac:26`
///     (`AC_SEARCH_LIBS([sin], [m], ...)`) agree that the mathematical library
///     is the one external link dependency, and no other system library is
///     named by either; `addGraph` links exactly that one.
///
/// The same file serves both linkages. Upstream's template has no linkage-
/// dependent field, and it could not have one: the four headers declare no
/// export or import macro, so there is no define a consumer needs for one
/// delivery and not the other. `Libs:` is `-L"${libdir}" -lerfa` in both,
/// because the library's *name* does not change with linkage -- the linker
/// resolves `-lerfa` to `lib erfa.a` or, through the `lib erfa.so` link, to
/// the shared object.
fn addPkgConfig(b: *std.Build) void {
    const template = readPackageFile(b, "erfa.pc.in");
    var text = std.mem.replaceOwned(u8, b.allocator, template, "@prefix@", "${pcfiledir}/../..") catch @panic("OOM");
    text = std.mem.replaceOwned(u8, b.allocator, text, "@exec_prefix@", "${prefix}") catch @panic("OOM");
    text = std.mem.replaceOwned(u8, b.allocator, text, "@libdir@", "${prefix}/lib") catch @panic("OOM");
    text = std.mem.replaceOwned(u8, b.allocator, text, "@includedir@", "${prefix}/include") catch @panic("OOM");
    text = std.mem.replaceOwned(u8, b.allocator, text, "@VERSION@", package_version) catch @panic("OOM");
    text = std.mem.replaceOwned(u8, b.allocator, text, "@LIBS@", "-lm") catch @panic("OOM");

    // Generated into the build cache and installed from there, because the file
    // describes an install prefix rather than anything in this tree.
    const files = b.addWriteFiles();
    b.getInstallStep().dependOn(&b.addInstallFileWithDir(
        files.add("erfa.pc", text),
        .lib,
        "pkgconfig/erfa.pc",
    ).step);
}

/// Installs the carried licence, provenance and documentation material.
///
/// A private repository removes no upstream obligation, so the two upstream
/// texts travel with every artefact. They land in one place with the rest of
/// the records: `share/licenses/erfa/` for terms and provenance,
/// `share/doc/erfa/` for upstream's own documentation and this fork's
/// preserved copy of it.
fn installRecords(b: *std.Build) void {
    for (licence_records) |record| {
        b.getInstallStep().dependOn(&b.addInstallFileWithDir(
            b.path(record),
            .{ .custom = b.fmt("share/licenses/{s}", .{lib_name}) },
            record,
        ).step);
    }
    for (doc_records) |record| {
        b.getInstallStep().dependOn(&b.addInstallFileWithDir(
            b.path(record),
            .{ .custom = b.fmt("share/doc/{s}", .{lib_name}) },
            record,
        ).step);
    }
}

/// Compiles the library, the translated header, the facade, the exercise, the
/// tests, the smoke example and both upstream validation programs for one
/// target, and attaches every one of them to `step`. Nothing is run: a
/// cross-compiled binary cannot run on the host, and a result reported from
/// such a compile would be a claim about execution that did not happen.
///
/// `linkage` is the linkage the caller asked for, so this compiles the artefact
/// that the published graph would really deliver rather than an archive nobody
/// asked for. A shared object is a new artefact class and not a linkage flip,
/// so `check -Dlinkage=dynamic` has to walk it or it says nothing about it.
///
/// A row that cannot carry what the caller asked for becomes an explicit
/// failing step carrying the reason, and nothing at all is compiled for it.
/// That is the honest result of `zig build check -Dlinkage=dynamic`: one
/// refused row, the other five still compiled, and no archive handed back
/// under the flag that asked for a shared object. The row is not dropped, not
/// relabelled and not answered with something else, so it cannot pass by
/// omission.
///
/// A step rather than a `@panic` here, and the difference is what the two are
/// for. The selected target's own graph has already been refused in
/// `resolved_linkage` before this runs -- `zig build -Dtarget=wasm32-wasi
/// -Dlinkage=dynamic` stops at configure -- so this branch is only ever
/// reached for a row nobody named with `-Dtarget=`. Aborting there would take
/// down a native `zig build install`, which is entirely valid, over a target
/// that step never compiles.
fn addTargetCheck(
    b: *std.Build,
    step: *std.Build.Step,
    query: std.Target.Query,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
) void {
    const target = b.resolveTargetQuery(query);
    const prefix = graph_prefix(b, target);

    if (linkage == .dynamic) {
        if (shared_object_refusal(b, target)) |reason| {
            step.dependOn(&b.addFail(b.fmt(
                "erfa: check row {s}: {s} No artifact was built for this row, and nothing was substituted for it.",
                .{ prefix, reason },
            )).step);
            return;
        }
    }

    const checked = addGraph(b, .{
        .target = target,
        .optimize = optimize,
        .public = false,
        .linkage = linkage,
        .runtime_loaded = runtime_loaded,
    });
    const programs = addPrograms(b, target, optimize, checked, prefix);
    step.dependOn(&checked.c_lib.step);
    step.dependOn(&programs.tests.step);
    step.dependOn(&programs.exercise.step);
    step.dependOn(&programs.smoke.step);
    for (programs.upstream) |program| step.dependOn(&program.step);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // The delivery. `static` is the default because it is what this graph
    // hard-coded before the option existed, and every recorded gate in this
    // repository's history observed that artefact.
    const requested_linkage = b.option(
        std.builtin.LinkMode,
        "linkage",
        "Deliver the native library as a static archive (the default, and " ++
            "exactly what this package produced before the option existed) or " ++
            "as a real shared object carrying upstream's own libtool ABI " ++
            "version, liberfa.so.1.8.1 with the soname liberfa.so.1. This " ++
            "selects the delivery and never the dispatch: the same 249 sources, " ++
            "the same generated config.h, the same four headers, the same " ++
            "translation, the same facade and the same programs are compiled " ++
            "either way. A target whose platform cannot carry a shared object " ++
            "at all -- wasm32-wasi in this package's own matrix, though a " ++
            "Windows target can carry one and is not in that class -- and " ++
            "requesting one there is refused rather than answered with a " ++
            "different artefact. For the selected target that refusal stops the " ++
            "build at configure time; inside `check` the unsupported row becomes " ++
            "an explicit failing step and every other row is still compiled.",
    ) orelse .static;

    // The dispatch, which is a different decision and orthogonal to the one
    // above: this option says whether the facade's native calls go through a
    // link line or through a table an explicit `load(source)` fills. Under it
    // the library is still built and installed -- a caller may name the
    // provider this tree did build, or one it did not -- but nothing is linked
    // into the module. `addGraph` holds the whole branch.
    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Resolve the native entry points at run time instead of linking them, " ++
            "through one process-lifetime table an explicit load(source) fills. " ++
            "The facade keeps the same translated header, the same native types " ++
            "and the same public LoadSource/LoadError; each selected entry " ++
            "point becomes a dispatch through that table, and the module links " ++
            "no archive. Independent of -Dlinkage, which still decides which " ++
            "artefact this build delivers and installs. Default off, and a " ++
            "linked build is unchanged in every respect.",
    ) orelse false;

    const graph = addGraph(b, .{
        .target = target,
        .optimize = optimize,
        .public = true,
        .linkage = requested_linkage,
        .runtime_loaded = runtime_loaded,
    });
    const programs = addPrograms(b, target, optimize, graph, "");

    // `zig build` installs the artefact -- the archive, or the shared object
    // with its soname and version links under `-Dlinkage=dynamic` -- together
    // with the four headers upstream installs, the pkg-config metadata that
    // describes both, and every carried licence and provenance record. A
    // library and its headers with no link metadata and no licence material
    // beside them are a source drop, not a package.
    b.installArtifact(graph.c_lib);
    // `LICENSE` and `INFO` are also installed at the prefix root, which is
    // where this graph has always put them and where `README.md`'s layout
    // section names them. They are kept rather than moved: a gate or a
    // consumer recorded against that path would break for no gain, and the
    // two copies are the same bytes. `installRecords` below adds the complete
    // record set, which is where packaging and a system integration expect
    // licence material to live.
    b.installFile("LICENSE", "LICENSE");
    b.installFile("INFO", "INFO");
    addPkgConfig(b);
    installRecords(b);
    // It also compiles the smoke example and the facade exercise. Neither is
    // installed: they are the proof that the facade, the translated header,
    // the archive and libm agree, not deliverables. Compiling is `zig build`'s
    // job; executing them belongs to `smoke` and `test`.
    b.getInstallStep().dependOn(&programs.smoke.step);
    b.getInstallStep().dependOn(&programs.exercise.step);

    // A run step whose inputs did not change is otherwise served from the run
    // cache and never executes. For a program whose whole purpose is to run
    // and compare answers, that would report success without observing
    // anything, so each run below is marked as having side effects.
    const run_smoke = b.addRunArtifact(programs.smoke);
    run_smoke.has_side_effects = true;
    // The provider a runtime-loading build is told to open arrives behind `--`,
    // so the arguments the caller typed belong to the program, not the build.
    if (b.args) |args| run_smoke.addArgs(args);
    // `zig build smoke` deliberately does not pull in the install step:
    // installing is `zig build`'s job, and conflating the two would make a
    // smoke run depend on the install layout.
    b.step("smoke", "Run the smoke example").dependOn(&run_smoke.step);

    const consumer_mod = b.createModule(.{
        .root_source_file = b.path("consumer/src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    consumer_mod.addImport(lib_name, graph.module);
    const consumer = b.addExecutable(.{
        .use_llvm = true,
        .name = "erfa-consumer",
        .root_module = consumer_mod,
    });
    const run_consumer = b.addRunArtifact(consumer);
    run_consumer.has_side_effects = true;
    // The provider a runtime-loading build is told to open arrives behind `--`,
    // exactly as it does for `smoke` above. Without this, `zig build consumer --
    // --provider <path>` drops the flag, the program finds no `ERFA_TEST_PROVIDER`
    // either, and it exits telling the caller to pass the flag they just passed.
    if (b.args) |args| run_consumer.addArgs(args);
    b.step("consumer", "Run the module consumer").dependOn(&run_consumer.step);

    const run_tests = b.addRunArtifact(programs.tests);
    run_tests.has_side_effects = true;
    const run_exercise = b.addRunArtifact(programs.exercise);
    run_exercise.has_side_effects = true;
    // Unconditional, for every target the caller selected and the host
    // included. What then happens to the binaries is the caller's business and
    // each outcome is reportable as what it is: a host target executes, a
    // foreign target executes through whatever executor the driver supplies,
    // and a foreign target with no executor available is skipped with its
    // compile dependencies intact, which is build-only coverage and never a
    // pass. `cross-test.profile.sh` is this package's settings half of that
    // arrangement; deciding the policy belongs to the driver that owns the
    // step.
    const test_step = b.step("test", "Run the behavioural tests and the facade exercise for the selected target");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_exercise.step);

    // Upstream's own validation programs, run here and nowhere else. They are
    // the native oracle: `t_erfa_c.c` carries the expected values inherited
    // from SOFA's validation suite, and `t_erfa_c_extra.c` checks the version
    // functions and the leap-second table. Both signal failure through their
    // exit status, so a non-zero exit from either is a failed gate.
    var upstream_runs: [upstream_validation_programs.len]*std.Build.Step.Run = undefined;
    for (programs.upstream, 0..) |program, i| {
        const run = b.addRunArtifact(program);
        run.has_side_effects = true;
        upstream_runs[i] = run;
    }
    const upstream_step = b.step("upstream-test", "Run upstream's own t_erfa_c and t_erfa_c_extra validation programs");
    for (upstream_runs) |run| upstream_step.dependOn(&run.step);

    const check_step = b.step(
        "check",
        "Compile the C core, the translated headers, the facade, the exercise, the tests, the smoke example and both upstream validation programs for the six-target matrix, running nothing",
    );
    if (target_was_named(b)) {
        addTargetCheck(b, check_step, target.query, optimize, requested_linkage, runtime_loaded);
    } else {
        for (check_targets) |query| addTargetCheck(b, check_step, query, optimize, requested_linkage, runtime_loaded);
    }

    // Which artefact this configuration delivers, and for which target, is a
    // fact worth reading out of the build rather than inferring from a cache
    // directory. These are configure-time lines, not gate results: nothing has
    // been compiled when they print.
    std.debug.print("erfa: {s}, {d} core translation units, 4 public headers, config.h generated from configure.ac and m4/erfa-numver.m4\n", .{
        delivered_artifact_name(b, target, graph.linkage),
        core_sources.len,
    });
    if (runtime_loaded) {
        // Dispatch is a separate fact from delivery, and this line is what
        // keeps "the library is still built and installed" from reading as "the
        // module links it". Under this option nothing is linked into the
        // module -- neither the archive this tree compiled nor an installed
        // system library -- and the symbols arrive through the platform loader
        // when a caller names a provider with an explicit load(source).
        std.debug.print(
            "erfa: provider dispatch (-Druntime=true); no library is linked " ++
                "into the module, and a provider is named by an explicit " ++
                "load(source). The artefact above is still built and installed.\n",
            .{},
        );
    }
}
