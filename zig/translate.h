/* Aggregate header for translate-c.
 *
 * This file is fork-authored and is the only new C file this package adds.
 * It declares no ERFA declaration of its own: it names the four headers
 * upstream ships and installs, in upstream's own spelling, so that `pub const c`
 * in the Zig facade is a translation of ERFA's published API and nothing else.
 * The only declarations below are the two integer typedefs the compiler itself
 * owns and no header declares; see "The compiler's own typedefs" below.
 *
 * Why all four, and why in this order:
 *
 *   `src/Makefile.am:37` names exactly these as `include_HEADERS`, and
 *   `src/meson.build:46` installs the same four through `install_headers`.
 *   A translation that reached only some of them would describe a subset of
 *   the interface upstream publishes, and the four are not nested inside one
 *   another:
 *
 *     * `erfa.h` does *not* include `erfam.h`. Upstream says so in its own
 *       README: "one now has to explicitly include `erfam.h` to use its
 *       macros defining constants, etc." Upstream's own oracle does the same
 *       thing -- `src/t_erfa_c.c:1-2` writes `#include <erfa.h>` and
 *       `#include "erfam.h"` side by side -- so naming one without the other
 *       would be a spelling no upstream file uses.
 *     * `erfam.h` carries the constants every caller of the `era*` routines
 *       reads (`ERFA_DJM0`, `ERFA_WGS84` and its siblings, `erfam.h:112-114`
 *       and the rest of that file).
 *     * `erfaextra.h` carries the five version functions and the
 *       `eraLEAPSECOND` struct (`erfaextra.h:34-75`). ERFA is not SOFA-derived
 *       here and the struct is the parameter type of the leap-second getter
 *       and setter, so a translation without it cannot describe those two
 *       functions at all.
 *     * `erfadatextra.h` adds `eraDatini` and, at the end of the file, the
 *       `ERFA_THREAD_LOCAL` chain (`erfadatextra.h:38-50`) that
 *       `src/erfadatextra.c` uses for the leap-second table's active state.
 *       It includes `erfaextra.h` itself (`erfadatextra.h:14`), so ordering it
 *       after `erfaextra.h` is what upstream's own files do and is harmless;
 *       both headers are include-guarded, so this is order-independent.
 *
 * Why angle brackets:
 *
 *   Upstream's own build compiles these translation units with `src/` on the
 *   include path (`src/meson.build:45`, `declare_dependency(...,
 *   include_directories: '.')`) and installs the four headers flat, with no
 *   `erfa/` directory in between (`src/Makefile.am:37`). `build.zig` therefore
 *   puts `src/` on the translation's include path and installs the four into
 *   the artifact's header root at their own names, and the angle brackets here
 *   resolve to exactly the files that get installed.
 *
 * The compiler's own typedefs:
 *
 *   `__int128_t` and `__uint128_t` belong to the compiler rather than to a
 *   header: Clang declares them next to the `__int128` primitive it provides,
 *   and no header declares them. A C library header that spells one therefore
 *   reaches a name the translated text never defines, and `erfa.h:15`'s
 *   `<math.h>` does exactly that on NetBSD. `generic-netbsd/math.h:21` opens
 *   `<sys/cdefs.h>`, `:76` opens `<machine/cdefs.h>`, and
 *   `generic-netbsd/arm/cdefs.h:62-63` is
 *   `#if defined(__ARM_PCS_AAPCS64)` /
 *   `#define __ALIGNBYTES (sizeof(__int128_t) - 1)` -- the branch
 *   `aarch64-netbsd` takes, because `__ARM_PCS_AAPCS64` is one of the
 *   compiler's own predefines for AArch64. `-dD` keeps the spelling and the
 *   translated Zig comes out naming an identifier nothing in it declares:
 *   `pub const __ALIGNBYTES = __helpers.sizeof(__int128_t) - @as(c_int, 1);`,
 *   `use of undeclared identifier '__int128_t'` at
 *   `local://foundation-matrix-erfa-netbsd-preprocess-check-r1.log:3-6`.
 *
 *   Restating the two typedefs is what carries the declaration into the file
 *   the translator reads, on whichever route reads it. Nothing about the types
 *   is invented: `__int128` is the target's own primitive, and the guard is the
 *   compiler's own statement that this target has it, because Clang defines
 *   `__SIZEOF_INT128__` exactly when `TI.hasInt128Type()` holds for the target
 *   (`clang/lib/Frontend/InitPreprocessor.cpp:1173-1174` in upstream LLVM). A
 *   target without that extension declares neither name, and C permits a
 *   typedef to be restated for the type it already denotes, so a target whose
 *   headers declare these themselves ends on the same declaration.
 *   `x86_64-netbsd` spells `__ALIGNBYTES` as `sizeof(long) - 1`
 *   (`x86_64-netbsd-none/machine/cdefs.h:6`) and needs none of this; every
 *   32-bit NetBSD target leaves the guard false. The convention is the one
 *   `pcre2` and `lmdb` already carry in this workspace.
 *
 *   Nothing else of the C library is restated. `__ALIGNBYTES` itself, and every
 *   other macro and declaration NetBSD's headers contribute, stay exactly as
 *   the target's own headers spell them.
 *
 * Two front ends, and why this file has to be readable by both:
 *
 *   `build.zig` reads this header either through Aro, which is the C parser
 *   and preprocessor `zig translate-c` drives, or through the target's own C
 *   preprocessor with Aro parsing what that wrote. The second route exists
 *   because the NetBSD C library's `__END_DECLS` expands to
 *   `_Pragma("GCC visibility pop")` (`sys/cdefs.h:411-416,431-432`), which Aro
 *   cannot take in that form; `build.zig`'s `aggregateRoute` names which
 *   target gets which, and both routes read this same file.
 *
 *   So this file is a list of `#include`s and the two typedefs below, on both
 *   routes: on the first it is read as C, and on the second it is expanded into
 *   the text Aro then reads. An ERFA declaration written here would no longer
 *   be a declaration of its own on the second route, and would be a second
 *   spelling of upstream's on the first -- the published surface is upstream's,
 *   in upstream's spelling, and this aggregate is only the route to it. The two
 *   typedefs are the compiler's, restated rather than invented, and they are
 *   needed on both routes for one reason: `__ALIGNBYTES` names them.
 *
 *   What differs between the routes is what survives. `ERFA_TRANSLATE_H` below
 *   is this file's own guard: it is a macro in `pub const c` on the first
 *   route and is consumed by the preprocessor on the second, and nothing in
 *   this package reads it. Every declaration of the four headers survives both
 *   routes, and the macro definitions of `erfam.h` reach the translator on the
 *   second route because that route preprocesses with `-dD` -- which is why
 *   replacing an `#include` below with a copy of what it holds is never the
 *   fix for anything.
 *
 * `config.h`:
 *
 *   The version macros upstream generates (`PACKAGE_VERSION`,
 *   `PACKAGE_VERSION_MAJOR`, `PACKAGE_VERSION_MINOR`, `PACKAGE_VERSION_MICRO`,
 *   `SOFA_VERSION`) reach a *compiled* function -- `eraVersion` and its four
 *   siblings in `src/erfaversion.c:20-42` -- and not a declaration. So no
 *   public header here reads any of them and none is named below. `build.zig`
 *   still generates that header and puts its directory on the translation's
 *   include path next to the compilation's, and on the preprocessing line
 *   beside both, because every line that can resolve a name has to resolve
 *   the same one. If a future upstream header did read one, each of them would
 *   already find it rather than binding to whatever `config.h` a build machine
 *   happens to have.
 *
 * This header carries no licence granted by upstream's terms: it is
 * fork-authored. The terms that cover the four headers it names are recorded
 * per file in NOTICE.md.
 */

#ifndef ERFA_TRANSLATE_H
#define ERFA_TRANSLATE_H

/* The compiler's own typedefs for its 128-bit integer extension. No header
 * declares them, and NetBSD's __ALIGNBYTES names them without saying so, so
 * restating them here is what puts the declaration into the file
 * `zig translate-c` reads. The guard is the compiler's own capability macro,
 * so a target without __int128 declares neither. See the comment above. */
#if defined(__SIZEOF_INT128__)
typedef __int128 __int128_t;
typedef unsigned __int128 __uint128_t;
#endif

#include <erfa.h>
#include <erfam.h>
#include <erfaextra.h>
#include <erfadatextra.h>

#endif /* ERFA_TRANSLATE_H */