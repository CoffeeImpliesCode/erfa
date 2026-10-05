// SPDX-License-Identifier: BSD-3-Clause
//
//! ERFA's side of the runtime loader: the names its synchronization binding
//! has, and what it requires of a provider beyond resolving its symbols.
//!
//! Everything else about the runtime route is generic. `runtime/loader.zig` is
//! the state machine and the platform layer; `runtime/generate.zig` builds the
//! dispatch from whatever the translation step actually produced;
//! `runtime/graph.zig` wires them together. This file is what makes them ERFA's,
//! and it is the file another SDK replaces.
//!
//! ## What a provider must be
//!
//! Every `extern` the four selected headers declare, and nothing else.
//!
//! `zig/translate.h` includes `erfa.h`, `erfam.h`, `erfaextra.h` and
//! `erfadatextra.h`, and between them those three declare **255 functions**:
//! 247 in `erfa.h`, seven in `erfaextra.h` and one in `erfadatextra.h`. (249
//! is a different and also true fact - the number of translation units in
//! `core_sources` - and the two are not to be confused.)
//!
//! `erfa.h` declares those 247 entry points plus the two record layouts
//! `eraASTROM` (`erfa.h:22-40`) and `eraLDBODY`
//! (`erfa.h:44-48`); `erfaextra.h` declares the five version accessors and the
//! `eraLEAPSECOND` record with `eraGetLeapSeconds` and `eraSetLeapSeconds`
//! (`erfaextra.h:34-75`); `erfadatextra.h` declares `eraDatini`
//! (`erfadatextra.h:23-24`). `erfam.h` declares no function at all: it is
//! `#define` constants only (`erfam.h:16-114`), which the translation step
//! evaluates into Zig `pub const` declarations.
//!
//! There is exactly one C library header in that set, and it is reached for its
//! declarations only: `erfa.h:15` includes `"math.h"`. Every `extern fn` that
//! `<math.h>` contributes is the C library's, not ERFA's, and
//! `runtime/graph.zig` names all of them so that none of them becomes a
//! load-time requirement. ERFA's own names cannot collide with that list:
//! every entry point upstream ships begins with `era`.
//!
//! No entry point is conditional. The 249 translation units in `core_sources`
//! contain exactly one preprocessor guard that is not a plain include guard,
//! `#ifdef HAVE_CONFIG_H` in `src/erfaversion.c:15-17`, and this build defines
//! that macro on the compile line *and* on the translation line
//! (`build.zig`, `addGraph`), so both halves of every build see it. A build
//! whose two halves disagreed would export `eraVersion` from one and not the
//! other, and `load` would report the missing name.
//!
//! ## The external ABI family
//!
//! ERFA's ABI is fixed by three things and by nothing else: the C ABI of the
//! target, the record layouts its headers declare, and the arithmetic library
//! it links. There is no allocator, no global registry, no callback and no
//! versioning scheme in the interface.
//!
//!   * **Scalars.** The whole interface is `int`, `double`, `char *`,
//!     `const char *` and pointers to those. `int` is the C `int` the header
//!     declares, which is 32-bit on every target this package builds for
//!     (`x86_64-linux-gnu`, `aarch64-linux-gnu`, `aarch64-macos-none`,
//!     `x86_64-windows-gnu`, `riscv64-linux-gnu`, `wasm32-wasi`); the facade
//!     passes it as `c_int` for that reason and never narrows or widens it. No
//!     type-width macro is read at run time, so there is nothing to renegotiate.
//!   * **Layout.** Two records cross the boundary by pointer and are written in
//!     place: `eraASTROM` (17 `double` members, three of them arrays, plus one
//!     `double [3][3]` at offset 88) and `eraLEAPSECOND` (`int`, `int`,
//!     `double`, from `erfaextra.h:69-72`). `eraLDBODY` is passed as a pointer
//!     to an array and never written. Every vector and matrix in the interface
//!     is a `double` array whose extent is in the parameter's own declaration,
//!     so the extents are part of the ABI and are read from the translated
//!     header rather than assumed: a caller that passed `[2][2]f64` where
//!     `double [2][3]` is declared has changed the interface.
//!   * **libm.** The compiled objects link `libm` and only `libm`
//!     (`configure.ac:26`, `src/meson.build:32`), for `sin`, `cos`, `tan`,
//!     `atan2`, `asin`, `sqrt` and friends. A provider is a shared object, so
//!     its own `DT_NEEDED` has to resolve those: a provider built against a
//!     different libm, or a statically linked libm inside the provider, is a
//!     different floating-point environment and therefore not an interchangeable
//!     provider, however well its symbols resolve. This is a real boundary and
//!     nothing in this file can establish it; it is named so that a caller knows
//!     what "a compatible provider" has to mean.
//!   * **Thread-local state, or not.** The leap-second table's active state is
//!     declared `static ERFA_THREAD_LOCAL eraLEAPSECOND *changes` and
//!     `static ERFA_THREAD_LOCAL int NDAT` (`src/erfadatextra.c:22-23`), and
//!     whether that is thread-local storage at all is decided by the macro
//!     chain in `erfadatextra.h:38-50`: C++11 or C23 `thread_local`, else C11
//!     `_Thread_local`, else MSVC `__declspec(thread)`, else `__thread`, else
//!     **nothing**. Which branch a given provider took is not knowable here and
//!     not knowable from a compile of this tree: `build.zig` pins no `-std=`
//!     and never defines `ERFA_THREAD_LOCAL`, so the answer is whatever the
//!     compiler's own default dialect selects for each target, and a target
//!     landing on the empty branch compiles and runs with no diagnostic. This
//!     file therefore states no guarantee: a provider built on one of the
//!     first four branches has per-thread storage and a replacement on one
//!     thread is invisible to the others, and a provider built on the empty
//!     branch has one process-global table. The state belongs to the *provider*
//!     either way - this dispatch never holds a copy of it, and
//!     `leap.getLeapSeconds` returns a borrow of the provider's own storage
//!     through the pointer the provider hands back - and the two are different
//!     thread-safety contracts, so a process-global provider is not an
//!     interchangeable provider. Nothing in `validate` can tell them apart.
//!   * **No allocator.** Nothing in the four headers calls `malloc`, and no
//!     entry point takes a function pointer. There is nothing for a caller to
//!     install and nothing that can fail for want of memory.
//!   * **No versioning scheme.** ERFA has no symbol suffix, no ordinal and no
//!     `dlsym` versioning to agree on. `eraVersion`, `eraVersionMajor`,
//!     `eraVersionMinor`, `eraVersionMicro` and `eraSofaVersion`
//!     (`erfaextra.h:34-62`) are reporting functions, not an ABI negotiation.
//!
//! ## What `validate` actually checks
//!
//! Two things, and neither of them is a version word.
//!
//!   1. `eraSofaVersion()` answers with a non-empty NUL-terminated string. That
//!      is a check that the entry point behaves as a `const char *` returning
//!      function, through a pointer resolved by this dispatch.
//!   2. `eraGetLeapSeconds()` returns a positive count and a non-null table,
//!      and every entry of that table is self-consistent: the months are in
//!      1-12, the `(iyear, month)` pairs strictly increase, and `delat` is
//!      positive and strictly increases.
//!
//! The second is the load-bearing one, and it is a layout check rather than a
//! data check. It reads `count` records through a pointer the provider owns,
//! using *this* dispatch's `eraLEAPSECOND`. A provider whose `eraLEAPSECOND`
//! laid the members out differently - a `float` delta, a swapped pair, a
//! different integer width, a packed record - would have those bytes read at the
//! wrong offsets and would fail this walk rather than hand back nonsense. It
//! also establishes that the provider carries this fork's leap-second state at
//! all: `src/erfadatextra.c` was added after the v2.0.1 tag, so a released
//! `liberfa` 2.0.1 does not export `eraGetLeapSeconds` and is refused
//! by name, before it reaches this file.
//!
//! It runs on the loading thread, on a table that nothing has touched yet: a
//! fresh `NDAT` is `-1`, so the first `eraGetLeapSeconds` initialises the table
//! from `dat.c`'s built-in `_changes` (`src/dat.c:150-193`, `:202`) through
//! `eraDatini`. A caller who has installed their own table has not done so yet,
//! so the answer is the provider's own.
//!
//! ## What is not proof
//!
//! Resolving the symbols and passing these two checks is a boundary, not a
//! verdict. Nothing here establishes that a provider's `sin` is the same `sin`,
//! that its `eraASTROM` members are in the order this header reads them, or that
//! its arithmetic rounds the way this build's does. A provider that resolves and
//! passes and still differs will fail later, loudly, in ERFA's own code, where
//! the algorithm names the quantity. This file does not pretend to add a check
//! it cannot make, and it does not add a warning in place of one either.

const rt = @import("rt");

/// The synchronization this loader calls, bound by exact name.
///
/// The names below are `runtime/sync.h` compiled with
/// `RT_SYNC_PREFIX=erfa_rt`, which is what `runtime/graph.zig` passes. Two
/// spellings of that prefix have to agree: this file names the symbols, and
/// graph.zig defines the macro. A build where they disagree does not link, and
/// that is the whole error report: there is no runtime path that could hide it.
///
/// The core in `runtime/loader.zig` never names a symbol of its own, which is
/// what lets two SDKs, or two configurations of one SDK, hold their own loader
/// state in one process without sharing any of it.
pub const Sync = struct {
    extern fn erfa_rt_lock() void;
    extern fn erfa_rt_unlock() void;
    extern fn erfa_rt_wait() void;
    extern fn erfa_rt_broadcast() void;
    // `unsigned long long`. Declared as u64, which is the same type in every
    // ABI this SDK targets: 64-bit on x86_64, aarch64, riscv64 and wasm32.
    extern fn erfa_rt_thread_self() u64;

    pub fn lock() void {
        erfa_rt_lock();
    }
    pub fn unlock() void {
        erfa_rt_unlock();
    }
    pub fn wait() void {
        erfa_rt_wait();
    }
    pub fn broadcast() void {
        erfa_rt_broadcast();
    }
    pub fn threadSelf() u64 {
        return erfa_rt_thread_self();
    }
};

/// The lowest year a leap-second record can name, and the highest.
///
/// `eraDat` rejects a year before 1960 and warns for one more than five past
/// its release year of 2023 (`src/dat.c:65-74`), so no table upstream builds or
/// ships can name a year outside this range. These are bounds, not expected
/// values: a provider's own table is read for order and shape, not compared
/// against a list this file holds.
const table_year_low: i32 = 1900;
const table_year_high: i32 = 2200;

/// The loader's configuration for this SDK, given the dispatch that owns the
/// table.
///
/// `dispatch` is the generated module, passed as a type by the dispatch itself
/// so that this file never has to import it. The direction is one-way on
/// purpose: the descriptor knows what the loader needs, the dispatch knows what
/// the header said, and neither imports the other.
pub fn Config(comptime dispatch: type) type {
    return struct {
        /// Named in the pre-load panic, so the message says which library was
        /// reached for before it was loaded.
        pub const library_name = "erfa";

        /// The table the generated dispatch declares, and the symbols it needs
        /// to fill it. Both come from the translated header, not from this file.
        pub const table = dispatch.Table;
        pub const symbols = dispatch.symbols;
        pub const optional_symbols = dispatch.optional_symbols;

        /// This project's namespaced synchronization binding.
        pub const sync = Sync;

        pub fn tablePtr() *table {
            return dispatch.tablePtr();
        }

        pub fn ready() *rt.Ready {
            return &dispatch.ready;
        }

        pub fn assign(comptime index: usize, dst: *table, address: *const anyopaque) void {
            dispatch.assign(index, dst, address);
        }

        pub inline fn assignOptional(comptime index: usize, dst: *table, address: *const anyopaque) void {
            dispatch.assignOptional(index, dst, address);
        }

        pub inline fn assignMissing(comptime index: usize, dst: *table) void {
            dispatch.assignMissing(index, dst);
        }

        /// The library-specific checks, run after every symbol resolved and
        /// before anything is published.
        pub fn validate(dst: *const table) ?[]const u8 {
            if (dst.eraSofaVersion()[0] == 0) {
                return "eraSofaVersion() answered with an empty string, so this " ++
                    "provider is not the library this header describes";
            }
            return leapTableShape(dst);
        }

        /// Walk the provider's own leap-second table through this dispatch's
        /// record layout.
        ///
        /// This is the one check here that reads memory the provider owns rather
        /// than a value it computed, and it is deliberate: a provider whose
        /// `eraLEAPSECOND` disagrees about its own layout fails the walk instead
        /// of returning records whose fields are bytes at the wrong offsets.
        fn leapTableShape(dst: *const table) ?[]const u8 {
            var entries: [*c]dispatch.eraLEAPSECOND = undefined;
            const count = dst.eraGetLeapSeconds(&entries);
            if (count <= 0) {
                return "eraGetLeapSeconds() reported no leap-second table, so this " ++
                    "provider has nothing for eraDat to read";
            }
            if (entries == null) {
                return "eraGetLeapSeconds() reported a table but returned a null " ++
                    "pointer, so this provider's leap-second state is not the " ++
                    "one the headers describe";
            }

            var index: c_int = 0;
            var previous_year: c_int = 0;
            var previous_month: c_int = 0;
            while (index < count) : (index += 1) {
                const entry = entries[@intCast(index)];
                if (entry.month < 1 or entry.month > 12) {
                    return "a leap-second record names a month outside 1-12, so " ++
                        "this provider's eraLEAPSECOND layout is not the one " ++
                        "these headers describe";
                }
                if (entry.iyear < table_year_low or entry.iyear > table_year_high) {
                    return "a leap-second record names a year outside the range " ++
                        "eraDat accepts, so this provider's eraLEAPSECOND layout " ++
                        "is not the one these headers describe";
                }
                if (index > 0) {
                    const ordered = entry.iyear > previous_year or
                        (entry.iyear == previous_year and entry.month > previous_month);
                    if (!ordered) {
                        return "the leap-second table is not sorted by year and " ++
                            "month, so this provider's eraLEAPSECOND layout is not " ++
                            "the one these headers describe";
                    }
                }
                if (entry.delat <= 0.0) {
                    return "a leap-second record has a non-positive TAI-UTC, so " ++
                        "this provider's eraLEAPSECOND layout is not the one " ++
                        "these headers describe";
                }
                previous_year = entry.iyear;
                previous_month = entry.month;
            }
            return null;
        }
    };
}