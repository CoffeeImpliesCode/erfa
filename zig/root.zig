//! Zig facade over the canonical ERFA C implementation, the BSD-relicensed
//! descendant of the IAU SOFA library.
//!
//! No algorithm is reimplemented here. Every number this module returns is
//! produced by the C under `src/`, reached through `pub const c`, the module
//! `b.addTranslateC` produces from the four shipped public headers
//! (`erfa.h`, `erfam.h`, `erfaextra.h`, `erfadatextra.h`). What the facade
//! adds is what a C header cannot express: a signed status that a caller
//! cannot mistake for a boolean, a result record that says which outputs
//! exist, a closed set of time scales instead of a bare `char *`, and a
//! documented lifetime for the borrowed leap-second table.
//!
//! ## Import routes
//!
//! One Zig route is published: `dep.module("erfa")` in the dependent's
//! `build.zig`, which is `@import("erfa")` in source. The raw translated
//! header is `c` on that same module and is not published under a name of its
//! own, so the declarations and the library that satisfies them arrive through
//! one route. A C consumer takes the installed headers and archive instead;
//! `README.zig.md` names that layout.
//!
//! The shortest sequence that uses this module:
//!
//! ```zig
//! const std = @import("std");
//! const erfa = @import("erfa");
//!
//! pub fn main() !void {
//!     const date = erfa.calendar.cal2jd(2003, 6, 1).date orelse return;
//!     std.debug.print("{d}\n", .{date.sum()});
//! }
//! ```
//!
//! ## Status, warnings and sentinels
//!
//! Upstream returns `int` from about forty-seven of its routines, and that
//! integer is not a boolean. Zero means nothing to report; a positive value is
//! a warning whose outputs are computed and usable; a negative value is an
//! error. `eraPlan94` reports `+2` for failure to converge, `eraDat` reports
//! `+1` for a dubious year, and `eraUtcut1` copies a child's positive status
//! out while collapsing any negative child to `-1`
//! (`src/utcut1.c:86-90`). Nothing here collapses that to `bool`: every typed
//! entry point returns the integer in a `Status` next to the outputs.
//!
//! Sentinels are per path and are preserved as sentinels, never converted to
//! NaN. `eraGc2gd` writes `-1e9` into all three outputs on any error
//! (`src/gc2gd.c:75-79`); `eraGd2gc` writes zeros (`src/gd2gc.c:78`);
//! `eraEform` writes `a = f = 0.0` (`src/eform.c:86-89`); `eraDat` returns a
//! zero delta (`src/dat.c:106`, `:210`); `eraPlan94` zeroes the p-vector
//! (`src/plan94.c`). Where upstream writes nothing at all the corresponding
//! field is `null`, and the doc comment on that function says which case it
//! is.
//!
//! ## The two-part Julian Date
//!
//! Every date in ERFA is a pair whose *sum* is the value and whose
//! apportionment is arbitrary (`src/jd2cal.c:33-46`). `Date2` keeps both parts
//! exactly as upstream produced them and never normalises the second one.
//! That matters in three places a normalised fraction would be wrong:
//!
//!   * `eraDtf2d` sets the second part to the time of day divided by the day's
//!     length, so a time past midnight makes it exceed `1.0`
//!     (`src/dtf2d.c:144-148`); the accompanying status is `+2` or `+3`.
//!   * `eraDtf2d` and `eraD2dtf` use a quasi-JD day for UTC whose length may
//!     be 86399, 86400 or 86401 SI seconds, including the 1960-1972
//!     mini-leaps (`src/dtf2d.c:50-56`), so the parts are not a Julian day
//!     number plus a fraction.
//!   * `eraJd2cal` recovers the split with Kahan-Neumaier compensated
//!     summation, so re-splitting the result and adding is *not* lossless the
//!     way `(part_a, part_b)` carried through unchanged is.
//!
//! `Date2.sum()` is offered because a caller sometimes wants one number; it is
//! not a canonical form, and for UTC and UT1 the difference of two sums is
//! not a time interval (`src/dtf2d.c:67-72`).
//!
//! ## Leap seconds
//!
//! `leap.getLeapSeconds` returns a *borrow* of the table the calling thread is
//! using, and `leap.setLeapSeconds` *retains* the caller's pointer for that
//! thread (`src/erfadatextra.c:64-65`). Upstream copies nothing and frees
//! nothing, performs no sanity checks on the pointer or the count
//! (`src/erfadatextra.c:60-62`), and declares the state
//! `static ERFA_THREAD_LOCAL` (`src/erfadatextra.c:22-23`).
//!
//! **Whether that is thread-local storage at run time is not this module's to
//! promise.** The spelling is chosen by the chain in `src/erfadatextra.h:38-50`,
//! whose last arm expands to nothing, and this build pins no C dialect and
//! defines no `ERFA_THREAD_LOCAL`, so the compiled answer is whatever the
//! compiler's own default gives per target and is not knowable from this tree.
//! Everything below about "this thread" holds on the targets whose chain
//! selects a real branch; on the empty one the same statements hold with the
//! whole process in place of the thread. `runtime/library.zig` says the same
//! thing from the provider's side.
//!
//! Neither call is documented as invalidating the other: a borrow stays valid
//! until the table is replaced or reset *on the same thread*, and a table
//! handed to `setLeapSeconds` must outlive every later `eraDat` on that
//! thread. This module asserts no ownership, offers no `deinit`, and cannot
//! free what upstream never allocated.
//!
//! A replacement *does* take effect in `eraDat`, and this is worth stating
//! because it is easy to read the wrong way round. `eraDat` holds no state of
//! its own: `src/dat.c:199-200` declares `NDAT` and `changes` as ordinary
//! locals inside its body, without `static`, and re-reads them through
//! `eraDatini` on every call (`src/dat.c:202`). `eraDatini` returns the pair the
//! calling thread currently holds
//! (`src/erfadatextra.c:89-93`), so the next `eraDat` after a setter call sees
//! the new table. The neighbouring `static const` tables at
//! `src/dat.c:129` and `:150` are the file-static ones; the two at `:199-200`
//! deliberately are not.
//!
//! ## Const
//!
//! Upstream declares every parameter without `const` and does not write
//! through the vectors it only reads. The wrapper keeps `const` exactly where
//! the file was read and confirms it never assigns through that pointer; the
//! `@constCast` calls below mark those places and each names its evidence.
//! Where a parameter is genuinely written the wrapper exposes it as an output.
//!
//! ## Allocation
//!
//! There is none. Every routine writes into storage this module or the caller
//! owns: Zig locals, a caller slice, or one local `c.eraASTROM` whose members
//! are then copied out into the typed records. This module allocates nothing,
//! owns nothing, and has no `deinit`, because there is nothing to release and
//! nothing crosses into a third-party allocator.
//!
//! ## Two configurations: linked and runtime-loaded
//!
//! This module is built in one of two shapes, and `runtime_loaded` says which
//! at comptime.
//!
//! *Linked* is the default. The 249 compiled translation units are linked, `c`
//! is the translated header, and every call below is a direct call with no
//! table and no readiness check. There is no extra cost on that path at all:
//! the two public loader types below are declarations and nothing else, and no
//! other module is referenced until a runtime-loading build instantiates it.
//!
//! *Runtime-loaded* is opt-in with `-Druntime=true`. Nothing is linked; `c` is
//! a dispatch generated from the same translation step's output, and all 255
//! entry points the four headers declare - the 247 core routines of `erfa.h`,
//! the five version accessors and the two leap-second entry points of
//! `erfaextra.h`, and `eraDatini` - are resolved through the platform loader
//! when the caller calls
//!
//! ```zig
//! try erfa.load(.{ .path = "/usr/lib/liberfa.so.1" });
//! ```
//!
//! before using anything else. A call into a module that has not loaded stops
//! the program with a message naming the function, in every optimization
//! mode. That is a programming error rather than a recoverable condition: the
//! table does not exist yet, and there is no partial state to fall back on.
//! The load itself reports a missing file, a provider that does not export
//! what the header declares, a provider whose `eraLEAPSECOND` record does not
//! lay its members out as this header reads them, a request that cannot be
//! honoured because a different provider already won, or a reentrant call, as
//! errors rather than as a different library being loaded instead.
//!
//! `liberfa.so.1` is the soname this package's own shared object carries:
//! `configure.ac:20` records `ERFA_LIB_VERSION_INFO(9, 1, 8)`, libtool's
//! `(C - A).A.R` gives `9 - 8 = 1` for the soname number, which is what
//! `build.zig`'s `abi_version` and `meson.build`'s own derivation both reach.
//! `.path` names a file, so the versioned file name `liberfa.so.1.8.1` works
//! too, and any other spelling is a file the loader will not find.
//!
//! The provider is reached, never guessed. `.path` names a file and `.system`
//! names a library for the platform loader; neither falls back to the other,
//! the module has no unload and no reset, and it keeps the handle and its own
//! copy of the request to the end of the process.
//!
//! Nothing in this module snapshots the library's mutable state. The
//! leap-second table is the only such state there is, and its storage class
//! is whatever branch the provider's own `ERFA_THREAD_LOCAL` chain selected
//! (`src/erfadatextra.c:22-23`, `src/erfadatextra.h:38-50`), so per-thread on
//! a provider built on one of the first four arms and process-global on the
//! empty one. Either way `leap.getLeapSeconds` hands back a borrow of the
//! provider's own storage through the pointer the provider returned, and this
//! module copies nothing out of it. In a runtime-loading build that storage
//! lives in whichever provider was loaded; this module keeps nothing alive
//! itself.
//!
//! What a provider must be is stated in `runtime/library.zig`, next to the
//! external ABI boundary - scalars, record layouts, `libm` and the
//! thread-local question - and what is and is not checked about it.

const std = @import("std");

/// The translated ERFA headers: `erfa.h`, `erfam.h`, `erfaextra.h` and
/// `erfadatextra.h` exactly as upstream ships them.
///
/// This is the escape hatch for a routine the typed surface does not name, for
/// the `eraLEAPSECOND` and `eraASTROM` record layouts themselves, and for the
/// macro constants of `erfam.h`. It is the same module the facade calls, on the
/// same library, so importing the facade is all a dependent needs to reach it;
/// it is not published under a name of its own.
///
/// A caller that reaches past the facade gets upstream behaviour and inherits
/// every obligation upstream declares, including the positive-warning statuses
/// and the per-path sentinels named above.
///
/// In a runtime-loading build this module is a generated dispatch instead of
/// the translation step's own output. It publishes the same namespace: every
/// type and constant is re-exported from the translated header rather than
/// restated, so `LeapSecond` and `Astrom`'s C record are the same nominal
/// types either way and nothing here needs a cast. What differs is how a name
/// reaches the library. In the linked configuration it is a direct call; in
/// the runtime-loaded one it is a call through a table that `load` fills, and a
/// call before that fill stops the program with a message naming the function.
/// `runtime_loaded` says which configuration this build is, at comptime.
pub const c = @import("c");

/// The loader core, which is where a linked build's two public types come from.
///
/// It is imported only by the linked configuration. In a runtime-loading build
/// the dispatch carries its own copy of the same declarations, and this module
/// is never referenced, so it is never resolved and never compiled. Either way
/// there is exactly one `LoadSource` and one `LoadError` in a build, which is
/// what keeps them one type for a consumer that names them.
const rt = @import("rt");

/// Whether this module was configured to resolve its native symbols at run
/// time.
///
/// False for the ordinary build, where the compiled library is linked and `c`
/// is the translated header itself. True when the build generated a dispatch
/// that resolves the same symbols through the platform loader, in which case
/// `load` is the call that makes the library usable.
///
/// It is a comptime constant, so a consumer can write two different code paths
/// and have only the one it chose analyzed.
pub const runtime_loaded: bool = if (@hasDecl(c, "rt_runtime_loaded")) c.rt_runtime_loaded else false;

/// Which native library `load` should open.
///
/// `.path` is an explicit file path and `.system` is an explicit name for the
/// platform loader. There is no path-to-system fallback and no implicit
/// fallback of any kind; a request that cannot be honoured is an error, not a
/// different library.
pub const LoadSource = if (runtime_loaded) c.LoadSource else rt.LoadSource;

/// Every way `load` can decline.
///
/// Declared here, in the module a consumer imports, rather than only inside the
/// loader: the caller names the failure it is handling.
pub const LoadError = if (runtime_loaded) c.LoadError else rt.LoadError;

/// Load the native library this module dispatches to.
///
/// In a runtime-loading build this is the whole contract: call it once, then
/// use this module as if it were linked. Calling it again with the same request
/// succeeds and changes nothing; calling it with a different request after a
/// success is `ProviderMismatch`, and the library already in use stays in use.
/// A failed attempt publishes nothing and can be retried explicitly, by
/// calling this again: there is no automatic retry, and no implicit second
/// source.
///
/// It keeps the process handle and its own copy of the request to the end of
/// the process. There is no unload and no reset, because the table is
/// process-global state that other code may already have called through.
///
/// Safe to call from any thread. A thread that arrives while an attempt for the
/// same request is in flight waits for that attempt and gets its result,
/// whatever it was. A call from the thread that is running the attempt is
/// `ReentrantLoad` rather than a deadlock.
///
/// In a linked build there is no provider, no table and nothing to resolve, so
/// this stops the program with a message saying so instead of quietly
/// succeeding. `runtime_loaded` is false there, so a consumer that supports
/// both configurations can tell the two apart at comptime instead of meeting
/// this at run time.
pub fn load(source: LoadSource) LoadError!void {
    if (comptime !runtime_loaded) {
        std.debug.panic(
            "erfa: load was called on a linked build; this module is not " ++
                "runtime-loaded, so there is no library to load. Build with " ++
                "runtime loading configured, or do not call load.",
            .{},
        );
    }
    return c.load(source);
}

/// The request that succeeded, or null when nothing has loaded yet.
///
/// The answer is the loader's own retained copy and stays valid for the life of
/// the process. Null in a linked build, which has no request.
pub fn loadedSource() ?LoadSource {
    if (comptime !runtime_loaded) return null;
    return c.loadedSource();
}

/// The status integer upstream returns, kept as the integer it is.
///
/// The three predicates are the whole taxonomy: zero is neither a warning nor
/// an error, a positive value is a warning whose outputs were still computed,
/// and a negative value is an error. No routine in this module converts any of
/// the three into another, and no routine hides one behind a boolean.
pub const Status = struct {
    /// The signed integer upstream returned, unaltered.
    value: i32,

    /// The status of a call that reported nothing.
    pub const ok: Status = .{ .value = 0 };

    /// True when upstream reported neither a warning nor an error.
    pub fn isOk(self: Status) bool {
        return self.value == 0;
    }

    /// True when upstream reported a warning. The outputs are computed and
    /// usable; upstream chose a positive integer precisely so the caller can
    /// tell. Dropping it loses information the C interface carries.
    pub fn isWarning(self: Status) bool {
        return self.value > 0;
    }

    /// True when upstream reported an error. Which outputs exist after an
    /// error is per function, and each result type says so.
    pub fn isError(self: Status) bool {
        return self.value < 0;
    }

    pub fn format(self: Status, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("erfa.Status({d})", .{self.value});
    }
};

/// A two-part Julian Date: the value is `part_a + part_b`.
///
/// The split is upstream's choice and is preserved byte for byte. See the
/// module documentation for why the second part is deliberately not
/// normalised into `[0, 1)`.
pub const Date2 = struct {
    /// The first of upstream's two parts. For the MJD convention this is
    /// `ERFA_DJM0` (2400000.5); for the Julian Day Number convention it is the
    /// day number; upstream also uses the J2000 split, where it is 2451545.0.
    part_a: f64,

    /// The second of upstream's two parts, unnormalised. See the module
    /// documentation; it can exceed 1.0, and for a negative day fraction
    /// before 4713 BC it is negative.
    part_b: f64,

    /// The single Julian Date this pair denotes, when the caller's time scale
    /// makes that meaningful.
    ///
    /// This is a convenience, not a canonical form. For UTC and UT1 upstream
    /// states that the difference between two such results cannot be
    /// interpreted as a precise time interval (`src/dtf2d.c:67-72`).
    pub fn sum(self: Date2) f64 {
        return self.part_a + self.part_b;
    }
};

/// The time scales whose conversions this facade names.
///
/// Upstream selects behaviour with `strcmp(scale, "UTC")` on an exact,
/// upper-case string (`src/dtf2d.c:99`), so "utc" silently means something
/// else. This enum removes the spelling: the caller chooses a scale, and
/// `eraDtf2d`/`eraD2dtf` receive the exact string upstream expects.
pub const TimeScale = enum {
    /// International Atomic Time.
    tai,
    /// Terrestrial Time.
    tt,
    /// Universal Time.
    ut1,
    /// Coordinated Universal Time, with the leap-second convention.
    utc,
    /// Geocentric Coordinate Time.
    tcg,
    /// Barycentric Coordinate Time.
    tcb,
    /// Barycentric Dynamical Time.
    tdb,

    /// The C string this scale is passed as, including the terminating NUL.
    ///
    /// Only `"UTC"` selects the leap-second path; every other value is
    /// compared and rejected by upstream, so all six of them behave alike.
    pub fn code(self: TimeScale) [:0]const u8 {
        return switch (self) {
            .tai => "TAI",
            .tt => "TT",
            .ut1 => "UT1",
            .utc => "UTC",
            .tcg => "TCG",
            .tcb => "TCB",
            .tdb => "TDB",
        };
    }
};

/// The reference ellipsoids `eraEform` knows, by upstream's own identifiers.
///
/// The values are `ERFA_WGS84`, `ERFA_GRS80` and `ERFA_WGS72` from
/// `erfam.h:112-114`, read through the translated header rather than
/// restated, so this enum cannot drift from the C.
pub const Ellipsoid = enum(c_int) {
    /// World Geodetic System 1984.
    wgs84 = c.ERFA_WGS84,
    /// GRS80.
    grs80 = c.ERFA_GRS80,
    /// World Geodetic System 1972.
    wgs72 = c.ERFA_WGS72,

    /// The identifier upstream expects, i.e. the `n` argument of `eraEform`,
    /// `eraGc2gd` and `eraGd2gc`.
    pub fn id(self: Ellipsoid) c_int {
        return @intFromEnum(self);
    }
};

/// Which observed coordinates `eraAtoc13` and `eraAtoi13` are given in.
///
/// Upstream inspects only the first character of the string and treats
/// anything other than `R`/`r` and `H`/`h` as azimuth and zenith distance
/// (`src/atoc13.c:38-45`). The enum makes the third spelling explicit instead
/// of falling through.
pub const ObservationType = enum {
    /// Observed right ascension, CIO-based, and declination.
    right_ascension,
    /// Observed hour angle, west positive, and declination.
    hour_angle,
    /// Observed azimuth, north zero and east 90 degrees, and zenith distance.
    azimuth,

    /// The C string upstream is given, including the terminating NUL.
    pub fn code(self: ObservationType) [:0]const u8 {
        return switch (self) {
            .right_ascension => "R",
            .hour_angle => "H",
            .azimuth => "A",
        };
    }
};

/// Upstream's `eraLEAPSECOND` record, unchanged.
///
/// One entry of a leap-second table: the UTC date a step in TAI-UTC takes
/// effect and the new value in seconds. Declared by `erfaextra.h:69-72`; the
/// layout is taken from the translated header so it cannot disagree with the
/// library that fills it.
pub const LeapSecond = c.eraLEAPSECOND;

/// Star-independent astrometry parameters, named field by field for what
/// `eraApco` writes.
///
/// Upstream's record is `eraASTROM` (`erfa.h:22-40`), it is unchanged, and the
/// raw route publishes it as `c.eraASTROM`. Every member of it but `phi` is
/// assigned on the path `eraApco13` runs: `eraApcs` writes `pmt`, `eb`, `eh`,
/// `em`, `v`, `bm1` and `bpn` (`src/apcs.c:142-170`), and `eraApco` writes the
/// rest (`src/apco.c:182-220`). `phi` is declared by the header and assigned by
/// nothing in `src/`, so this type names the sixteen members that exist and
/// leaves the record layout itself to the raw route. Filling it copies sixteen
/// doubles out of the C record; nothing is allocated.
pub const Astrom = struct {
    /// PM time interval (SSB, Julian years).
    pmt: f64,
    /// SSB to observer, vector, au.
    eb: Vec3,
    /// Sun to observer, unit vector.
    eh: Vec3,
    /// Distance from Sun to observer, au.
    em: f64,
    /// Barycentric observer velocity, vector, units of c.
    v: Vec3,
    /// `sqrt(1 - |v|^2)`, the reciprocal of the Lorenz factor.
    bm1: f64,
    /// The CIO-based bias-precession-nutation matrix.
    bpn: Mat3,
    /// Longitude + s' + dERA(DUT), radians.
    along: f64,
    /// Polar motion xp with respect to the local meridian, radians.
    xpl: f64,
    /// Polar motion yp with respect to the local meridian, radians.
    ypl: f64,
    /// Sine of the geodetic latitude.
    sphi: f64,
    /// Cosine of the geodetic latitude.
    cphi: f64,
    /// Magnitude of the diurnal aberration vector. `eraApco` disables that step
    /// and writes `0.0` (`src/apco.c:204-205`); `eraApio` computes it.
    diurab: f64,
    /// The local Earth rotation angle, radians.
    eral: f64,
    /// Refraction constant A, radians.
    refa: f64,
    /// Refraction constant B, radians.
    refb: f64,
};

/// The part of the astrometry record `eraApio` writes.
///
/// `eraApio13` prepares parameters for the CIRS-to-observed transformation
/// only, and `eraApio` assigns just these nine members (`src/apio.c:140-166`).
/// `pmt`, `eb`, `eh`, `em`, `v`, `bm1` and `bpn` belong to the ICRS-to-observed
/// transformation: upstream leaves them exactly as the caller had them, which
/// is why `eraAtciq` can be handed a record a caller filled in earlier
/// (`src/atciq.c:75-84`). They are not here, because this module never gives
/// the caller a record to prefill.
pub const ObservedAstrom = struct {
    /// Longitude + s' + dERA(DUT), radians.
    along: f64,
    /// Polar motion xp with respect to the local meridian, radians.
    xpl: f64,
    /// Polar motion yp with respect to the local meridian, radians.
    ypl: f64,
    /// Sine of the geodetic latitude.
    sphi: f64,
    /// Cosine of the geodetic latitude.
    cphi: f64,
    /// Magnitude of the diurnal aberration vector.
    diurab: f64,
    /// The local Earth rotation angle, radians.
    eral: f64,
    /// Refraction constant A, radians.
    refa: f64,
    /// Refraction constant B, radians.
    refb: f64,
};

/// The sixteen members `eraApco` writes, taken out of upstream's record.
///
/// One struct copy, no allocation. `phi` is the member `eraASTROM` declares and
/// no routine assigns; it is dropped rather than published unset.
fn astromOf(record: c.eraASTROM) Astrom {
    return .{
        .pmt = record.pmt,
        .eb = record.eb,
        .eh = record.eh,
        .em = record.em,
        .v = record.v,
        .bm1 = record.bm1,
        .bpn = record.bpn,
        .along = record.along,
        .xpl = record.xpl,
        .ypl = record.ypl,
        .sphi = record.sphi,
        .cphi = record.cphi,
        .diurab = record.diurab,
        .eral = record.eral,
        .refa = record.refa,
        .refb = record.refb,
    };
}

/// The nine members `eraApio` writes, taken out of upstream's record.
///
/// The other members of `eraASTROM` are left untouched by upstream, so they
/// hold whatever the C record held and are not read here.
fn observedAstromOf(record: c.eraASTROM) ObservedAstrom {
    return .{
        .along = record.along,
        .xpl = record.xpl,
        .ypl = record.ypl,
        .sphi = record.sphi,
        .cphi = record.cphi,
        .diurab = record.diurab,
        .eral = record.eral,
        .refa = record.refa,
        .refb = record.refb,
    };
}

/// A Cartesian or geocentric three-vector, in whatever units the producing
/// function documents.
pub const Vec3 = [3]f64;

/// A 3x3 rotation matrix, row major, matching upstream's `double [3][3]`.
pub const Mat3 = [3][3]f64;

/// A calendar date with no time of day, the shape `eraJd2cal` and `eraD2dtf`
/// split out.
pub const CalendarDate = struct {
    /// Proleptic Gregorian year. `eraCal2jd` rejects years below -4799 and
    /// `eraJd2cal` accepts a total Julian Date from -68569.5 to 1e9.
    year: i32,
    /// Month, 1 to 12.
    month: i32,
    /// Day of month. Upstream validates it against the month length, taking
    /// leap years into account, but does not accept an almanac-style day 0 or
    /// day 32.
    day: i32,
};

/// A calendar date and a fraction of the day, from `eraJd2cal`.
pub const GregorianDate = struct {
    /// See `CalendarDate.year`.
    year: i32,
    /// See `CalendarDate.month`.
    month: i32,
    /// See `CalendarDate.day`.
    day: i32,

    /// Fraction of the day. `eraJd2cal` normalises this into `[0, 1)` using
    /// compensated summation, so for this one function a normalised fraction
    /// is what upstream itself produced.
    fraction: f64,
};

/// A calendar date and a fraction of the day rounded to `ndp` decimal places,
/// from `eraJdcalf`.
pub const RoundedCalendarDate = struct {
    /// See `CalendarDate.year`.
    year: i32,
    /// See `CalendarDate.month`.
    month: i32,
    /// See `CalendarDate.day`.
    day: i32,

    /// The fraction of the day in units of `10^-ndp`, i.e. 9999 means
    /// 0.9999. This is *not* normalised into `[0, 10000)`: a fraction that
    /// rounds up gives the full denominator, and the day is then the
    /// preceding one (`src/jdcalf.c:113-115`).
    fraction: i32,
};

/// A time of day broken into fields, from `eraD2dtf` or `eraD2tf`.
pub const TimeOfDay = struct {
    /// Hours, 0 to 23, or 24 when the rounded value has run past the end of
    /// the day and the caller's resolution is too coarse to notice
    /// (`src/d2tf.c:47-50` names this case the caller's to handle).
    hour: i32,
    /// Minutes, 0 to 59.
    minute: i32,
    /// Seconds, 0 to 59, or **60** at a leap second. `eraD2dtf` produces the
    /// 60 for a UTC day that ends in a leap second and the time is 23:59:60
    /// (`src/d2dtf.c:144-161`).
    second: i32,
    /// Fraction of a second in units of `10^-ndp`, i.e. 13599 with `ndp = 5`
    /// means 0.13599. Not normalised.
    fraction: i32,
};

/// The two observed angles a caller supplies to, and gets back from, the
/// CIRS-facing and ICRS-facing coordinate conversions.
pub const ObservedSpherical = struct {
    /// Observed right ascension (CIO-based, radians) or hour angle (radians,
    /// west positive), depending on the `ObservationType` used.
    first: f64,
    /// Observed declination (radians).
    second: f64,
};

/// Where an object is in the observer's sky, as `eraAtco13` and `eraAtio13`
/// return it.
pub const ObservedPlace = struct {
    /// Azimuth, radians, north zero and east 90 degrees.
    azimuth: f64,
    /// Zenith distance, radians.
    zenith_distance: f64,
    /// Hour angle, radians, west positive.
    hour_angle: f64,
    /// Declination, radians.
    declination: f64,
    /// Right ascension, radians.
    right_ascension: f64,
};

/// Nutation in longitude and obliquity, radians.
pub const Nutation = struct {
    /// Nutation in longitude, radians.
    dpsi: f64,
    /// Nutation in obliquity, radians.
    deps: f64,
};

/// The CIP X and Y coordinates, radians, from `eraFw2xy`.
pub const Cip = struct {
    /// CIP X coordinate.
    x: f64,
    /// CIP Y coordinate.
    y: f64,
};

/// The three IAU 1976 precession angles between two epochs, radians, from
/// `eraPrec76`.
pub const Prec76Angles = struct {
    /// Accumulated precession in longitude.
    zeta: f64,
    /// Accumulated precession in longitude, the second of the two.
    z: f64,
    /// Accumulated precession in obliquity.
    theta: f64,
};

/// The five rotation matrices and three angles `eraPn00`, `eraPn06`,
/// `eraPn00a`, `eraPn00b` and `eraPn06a` return together.
pub const PrecessionNutation = struct {
    /// Nutation in longitude, radians. `eraPn00` and `eraPn06` take this as
    /// an argument and return it unchanged; the `a` and `b` models compute it
    /// and ignore the argument.
    dpsi: f64,
    /// Nutation in obliquity, radians, returned the same way as `dpsi`.
    deps: f64,
    /// Mean obliquity of the ecliptic, radians.
    epsa: f64,
    /// GCRS to J2000.0, the frame bias.
    rb: Mat3,
    /// J2000.0 to date, precession only.
    rp: Mat3,
    /// J2000.0 to date, precession and frame bias.
    rbp: Mat3,
    /// J2000.0 to date, nutation only.
    rn: Mat3,
    /// GCRS to date, the combined bias-precession-nutation matrix.
    rbpn: Mat3,
};

/// A position and a velocity, the shape every ephemeris here returns.
///
/// The record is `extern` on purpose and for one reason: it has to *be* the
/// `double pv[2][3]` that every ERFA pv argument is declared as. Two `[3]f64`
/// members in an `extern struct` have exactly that layout - 48 bytes, no
/// padding, align 8 - so a `Pv` can be handed to C and written through as the
/// same six contiguous doubles, with no field moved and no copy made. The
/// field names and types are the ones a caller reads; only the layout is
/// pinned, and `pvPointer` below is what turns one into the other.
pub const Pv = extern struct {
    /// Position, au for `eraEpv00` and `eraMoon98` and au for `eraPlan94`'s
    /// heliocentric frame, per each function's own documentation.
    position: Vec3,
    /// Velocity, au/day for `eraEpv00` and `eraMoon98`; au/day for
    /// `eraPlan94`.
    velocity: Vec3,
};

comptime {
    // The claim the rest of this module makes about `Pv` is that it is
    // interchangeable with `c`'s `double [2][3]`. If a target ever disagreed
    // - a different `f64` alignment, say - this stops the build here rather
    // than at a `@ptrCast` in the middle of a wrapper.
    if (@sizeOf(Pv) != 2 * @sizeOf(Vec3) or @alignOf(Pv) != @alignOf(Vec3)) {
        @compileError("erfa: Pv no longer has the layout of double [2][3]");
    }
}

/// The `double pv[2][3]` view of a `Pv`, for any argument or result.
///
/// Pure reinterpretation, guaranteed by the `comptime` check on `Pv` above: the
/// same six contiguous doubles, no field moved, nothing copied.
///
/// The `@constCast` is sound only for a callee that *reads* its pv argument,
/// and it is used only where that has been read out of the source rather than
/// assumed. Of the pv arguments this module passes, every one is read-only in
/// upstream - `eraSxpv`, `eraS2xpv`, `eraPvu`, `eraPvup`, `eraPvdpv`,
/// `eraPvmpv`, `eraPvppv`, `eraPvxpv`, `eraRxpv`, `eraTrxpv`, `eraCpv`,
/// `eraPv2p`, `eraPv2s` - with one exception: `eraPvstar` replaces its own
/// `pv[1]` with the space-travelled velocity (`src/pvstar.c:133`). That is why
/// `vectors.pvstar` hands it a mutable copy of its own and every other wrapper
/// passes its argument straight through.
///
/// Upstream declares these parameters without `const` throughout, so keeping
/// them read-only is this module's decision, and it is the same one it makes
/// for `Vec3` and `Mat3`: the `@constCast` marks exactly the place the header's
/// missing `const` is given back.
inline fn pvPointer(pv: *const Pv) [*c][3]f64 {
    return @constCast(@ptrCast(pv));
}

/// The result of a conversion that produces one two-part date and a status.
///
/// `date` is `null` exactly when upstream returned before writing it. Which
/// statuses those are differs per function and is stated on each one.
pub const DateResult = struct {
    /// The integer upstream returned.
    status: Status,
    /// The converted date, or `null` when upstream wrote nothing.
    date: ?Date2,
};

/// The result of `calendar.cal2jd`.
pub const Cal2jdResult = struct {
    /// `0` OK, `-1` bad year, `-2` bad month, `-3` bad day.
    status: Status,
    /// The MJD zero point and the MJD for 0 h. `null` when the status is `-1`
    /// or `-2`, because upstream returns before writing either one
    /// (`src/cal2jd.c:68-69`); the `-3` case *does* write them
    /// (`src/cal2jd.c:80-84`) and is deliberately not `null` here.
    date: ?Date2,
};

/// The result of `calendar.jd2cal`.
pub const Jd2calResult = struct {
    /// `0` OK, `-1` unacceptable date.
    status: Status,
    /// The calendar date and fraction, or `null` when the status is `-1`.
    date: ?GregorianDate,
};

/// The result of `calendar.jdcalf`.
pub const JdcalfResult = struct {
    /// `0` OK, `-1` date out of range, `+1` `ndp` outside 0-9 and read as 0.
    status: Status,
    /// The rounded calendar date, or `null` when the status is `-1`.
    date: ?RoundedCalendarDate,
};

/// The result of `calendar.dtf2d`.
pub const Dtf2dResult = struct {
    /// `+3`, `+2`, `+1` for warnings, `0` OK, `-1` to `-6` for errors.
    status: Status,
    /// The two-part date, or `null` when the status is negative: upstream
    /// validates the calendar fields and returns before assigning
    /// (`src/dtf2d.c:125-141`, `:147-148`).
    date: ?Date2,
};

/// The result of `calendar.d2dtf`.
pub const D2dtfResult = struct {
    /// `+1` dubious year, `0` OK, `-1` unacceptable date.
    status: Status,
    /// The calendar date, or `null` when the status is `-1`.
    date: ?CalendarDate,
    /// The time of day, or `null` when the status is `-1`. Its `second` may
    /// be 60 at a UTC leap second.
    time: ?TimeOfDay,
};

/// The result of `calendar.d2tf`.
pub const D2tfResult = struct {
    /// The sign upstream computed: `'+'` or `'-'`.
    sign: u8,
    /// See `TimeOfDay`.
    hour: i32,
    /// See `TimeOfDay`.
    minute: i32,
    /// See `TimeOfDay`.
    second: i32,
    /// See `TimeOfDay`.
    fraction: i32,
};

/// The result of `calendar.tf2d`.
pub const Tf2dResult = struct {
    /// `0` OK, `+1` hour out of range, `+2` minute out of range, `+3`
    /// second out of range. Only the first failure is reported
    /// (`src/tf2d.c:51-55`).
    status: Status,
    /// The interval in days. Upstream computes it even when a range check
    /// fails, so this is present for every status including `0`.
    days: f64,
};

/// The result of `calendar.tf2a`.
pub const Tf2aResult = struct {
    /// `0` OK, or `+1`, `+2`, `+3` as for `tf2d`.
    status: Status,
    /// The angle in radians, computed even when a range check fails.
    radians: f64,
};

/// The result of `calendar.af2a`.
pub const Af2aResult = struct {
    /// `0` OK, `+1` degrees out of range, `+2` arcminutes out of range,
    /// `+3` arcseconds out of range.
    status: Status,
    /// The angle in radians, computed even when a range check fails.
    radians: f64,
};

/// The result of `timescale.dat`.
pub const DatResult = struct {
    /// `+1` dubious year, `0` OK, `-1` to `-5` errors.
    status: Status,
    /// TAI minus UTC in seconds. Upstream returns exactly `0.0` whenever no
    /// valid result is available (`src/dat.c:106`, `:210`), so this is never
    /// absent and never NaN.
    delta_at: f64,
};

/// The result of `geodetic.eform`.
pub const EformResult = struct {
    /// `0` OK, `-1` illegal identifier.
    status: Status,
    /// Equatorial radius in metres. Upstream writes `0.0` on `-1`
    /// (`src/eform.c:86-89`).
    equatorial_radius: f64,
    /// Flatting, around 1/298. Upstream writes `0.0` on `-1`.
    flattening: f64,
};

/// A geodetic longitude, latitude and height, as `eraGc2gd` and `eraGc2gde`
/// produce them.
pub const Geodetic = struct {
    /// Longitude, radians, east positive.
    longitude: f64,
    /// Geodetic latitude, radians.
    latitude: f64,
    /// Height above the ellipsoid, metres when the ellipsoid radius is in
    /// metres.
    height: f64,
};

/// The result of `geodetic.gc2gd`.
pub const Gc2gdResult = struct {
    /// `0` OK, `-1` illegal identifier, `-2` internal error.
    status: Status,
    /// Always present. Upstream sets all three fields to `-1e9` on any error
    /// (`src/gc2gd.c:75-79`), and that sentinel is preserved rather than
    /// turned into `null` or NaN.
    geodetic: Geodetic,
};

/// The result of `geodetic.gc2gde`.
pub const Gc2gdeResult = struct {
    /// `0` OK, `-1` illegal flattening, `-2` illegal radius.
    status: Status,
    /// `null` when the status is negative: upstream validates the ellipsoid
    /// before writing anything and leaves the outputs untouched on error
    /// (`src/gc2gde.c:44-46`, `:76-77`).
    geodetic: ?Geodetic,
};

/// The result of `geodetic.gd2gc`.
pub const Gd2gcResult = struct {
    /// `0` OK, `-1` illegal identifier, `-2` illegal case.
    status: Status,
    /// Always present. Upstream zeroes the vector on any error
    /// (`src/gd2gc.c:78`).
    cartesian: Vec3,
};

/// The result of `geodetic.gd2gce`.
pub const Gd2gceResult = struct {
    /// `0` OK, `-1` the divisor is not positive. No finite input reaches `-1`:
    /// upstream's guard is `d = cos(phi)^2 + w^2 sin(phi)^2 <= 0`
    /// (`src/gd2gce.c:73-74`) and both terms are non-negative, so the branch
    /// exists for arguments no double produces. It is still carried, because
    /// it is upstream's status ladder.
    status: Status,
    /// `null` when the status is negative: upstream returns before writing the
    /// vector (`src/gd2gce.c:74`), which is why nothing is left behind.
    cartesian: ?Vec3,
};

/// The result of `rotation.apco13`.
pub const Apco13Result = struct {
    /// `+1` dubious year, `0` OK, `-1` unacceptable date.
    status: Status,
    /// The astrometry parameters, or `null` when the status is `-1`: both of
    /// upstream's failure returns happen before anything is written
    /// (`src/apco13.c:190`, `:193`).
    astrom: ?Astrom,
    /// The equation of the origins, ERA - GST, radians, or `null` when the
    /// status is `-1`. Upstream computes it as `eraEors(r, s)` and calls it
    /// that (`src/apco13.c:54`, `:220-221`); it is *not* the equation of the
    /// equinoxes, which is a different quantity (`src/eors.c:21-27`).
    equation_of_origins: ?f64,
};

/// The result of `rotation.apio13`.
pub const Apio13Result = struct {
    /// `+1` dubious year, `0` OK, `-1` unacceptable date.
    status: Status,
    /// The CIRS-observed astrometry parameters, or `null` when the status is
    /// `-1`. Upstream fills a caller-supplied `eraASTROM` in place and writes
    /// only the members `ObservedAstrom` names; the ICRS-observed ones stay
    /// untouched, so they are not part of this record.
    astrom: ?ObservedAstrom,
};

/// The result of `rotation.atco13`.
pub const Atco13Result = struct {
    /// `+1` dubious year, `0` OK, `-1` unacceptable date.
    status: Status,
    /// Where the object is in the observer's sky, or `null` when the status is
    /// `-1`.
    place: ?ObservedPlace,
    /// The equation of the origins, ERA - GST, radians, or `null` when the
    /// status is `-1`, for the reason `Apco13Result` gives.
    equation_of_origins: ?f64,
};

/// The result of `rotation.atio13`.
pub const Atio13Result = struct {
    /// `+1` dubious year, `0` OK, `-1` unacceptable date.
    status: Status,
    /// Where the object is in the observer's sky, or `null` when the status is
    /// `-1`.
    place: ?ObservedPlace,
};

/// The result of `rotation.atoc13`.
pub const Atoc13Result = struct {
    /// `+1` dubious year, `0` OK, `-1` unacceptable date.
    status: Status,
    /// ICRS astrometric right ascension and declination, radians, or `null`
    /// when the status is `-1`.
    icrs: ?ObservedSpherical,
};

/// The result of `rotation.atoi13`.
pub const Atoi13Result = struct {
    /// `+1` dubious year, `0` OK, `-1` unacceptable date.
    status: Status,
    /// The CIRS observed angles, radians, or `null` when the status is `-1`.
    cirs: ?ObservedSpherical,
};

/// The result of `ephemeris.epv00`.
pub const Epv00Result = struct {
    /// `0` OK, `+1` the date is outside 1900-2100. Never negative, and the
    /// outputs are computed either way.
    status: Status,
    /// Heliocentric Earth position (au) and velocity (au/day).
    heliocentric: Pv,
    /// Barycentric Earth position (au) and velocity (au/day).
    barycentric: Pv,
};

/// The result of `ephemeris.plan94`.
pub const Plan94Result = struct {
    /// `-1` illegal planet number, `0` OK, `+1` year outside 1000-3000,
    /// `+2` failed to converge.
    status: Status,
    /// Heliocentric J2000.0 position (au) and velocity (au/day). Upstream
    /// zeroes all six components on `-1` (`src/plan94.c`).
    pv: Pv,
};

/// The result of `vectors.pn`: a modulus and the unit vector with that
/// modulus.
pub const PnResult = struct {
    /// The length of the input vector.
    modulus: f64,
    /// The input vector scaled to unit length. Zero when the input is zero.
    unit: Vec3,
};

/// The result of `leap.getLeapSeconds`.
pub const LeapTableResult = struct {
    /// The number of entries in the table, which is also the integer upstream
    /// returns, or `-1` for its internal error (`src/erfadatextra.c:34-37`).
    /// It is not `0`: a successful call always reports a positive count.
    status: Status,
    /// A borrow of the calling thread's active table, or `null` on the `-1`
    /// internal error.
    entries: ?[]const LeapSecond,
};

/// The leap-second table this thread is using, and the replacement for it.
///
/// "This thread" is upstream's `ERFA_THREAD_LOCAL` state
/// (`src/erfadatextra.c:22-23`) as the target's own dialect compiled it: the
/// chain in `src/erfadatextra.h:38-50` gives per-thread storage on its first
/// four arms and process-global storage on the empty one, and this build pins
/// no dialect and defines no `ERFA_THREAD_LOCAL`, so which one a target gets is
/// not knowable here. Both calls describe the calling thread wherever that
/// chain selected a real branch, and the whole process where it did not.
/// Nothing in this namespace copies, allocates or frees the table, because
/// upstream does none of those things.
pub const leap = struct {
    /// Borrow this thread's active leap-second table.
    ///
    /// The returned slice aliases upstream's own storage; nothing is copied
    /// (`src/erfadatextra.c:46`). The call forces lazy initialisation to the
    /// built-in table on first use (`src/erfadatextra.c:39-45`), so a first
    /// call can report the internal error `-1`.
    ///
    /// The borrow stays valid until `setLeapSeconds` replaces or resets the
    /// table *on this thread*. It is invalidated by no other call in this
    /// module, and where the `ERFA_THREAD_LOCAL` chain selected a real branch
    /// it is not invalidated by another thread's calls either, because another
    /// thread has its own table. On the empty branch there is one table for the
    /// process, so another thread's replacement does invalidate it.
    ///
    /// There is no `deinit`: upstream allocates nothing, so there is nothing
    /// for a caller to free and nothing this module could release on their
    /// behalf.
    pub fn getLeapSeconds() LeapTableResult {
        var table: [*c]LeapSecond = undefined;
        const count = c.eraGetLeapSeconds(&table);
        const status: Status = .{ .value = count };
        if (status.isError()) return .{ .status = status, .entries = null };
        const length: usize = @intCast(count);
        return .{ .status = status, .entries = table[0..length] };
    }

    /// Make `entries` this thread's leap-second table, retaining the caller's
    /// memory.
    ///
    /// Upstream stores the pointer itself and performs no sanity checks on it
    /// or on the count (`src/erfadatextra.c:60-65`). Consequently:
    ///
    ///   * the caller must keep `entries` alive until replacement or reset.
    ///     Mutate it only between calls on this thread, never during a call;
    ///     upstream rereads the retained storage;
    ///   * passing `null` is the reset: it stores a null pointer with a count
    ///     of zero, which is upstream's `count <= 0` case
    ///     (`src/erfadatextra.c:56-58`), after which the built-in table is
    ///     used again on the next `eraDat`-family call;
    ///   * a replacement takes effect in `eraDat` from the very next call on
    ///     this thread. `eraDat` keeps no snapshot: it re-reads the table
    ///     through `eraDatini` on every invocation (`src/dat.c:202`), and
    ///     `eraDatini` returns this thread's current pair
    ///     (`src/erfadatextra.c:89-93`);
    ///   * this invalidates any borrow previously returned by
    ///     `getLeapSeconds` on this thread, and on this thread only wherever
    ///     `ERFA_THREAD_LOCAL` selected a real branch. On the empty branch there
    ///     is one table for the process and every thread's borrow goes with it.
    ///   * preserve the built-in pre-1972 prefix. `eraDat` applies historical
    ///     drift by table index (the first 14 entries), not by entry year.
    ///     Append sorted future leap records rather than a short modern table.
    ///
    /// This module asserts no ownership of `entries` and takes no action to
    /// free it.
    pub fn setLeapSeconds(entries: ?[]const LeapSecond) void {
        if (entries) |table| {
            c.eraSetLeapSeconds(@constCast(table.ptr), @intCast(table.len));
        } else {
            c.eraSetLeapSeconds(null, 0);
        }
    }

    /// The active leap-second table, initialised from `builtin` if this thread
    /// has none yet: `leap.datini`, upstream's `eraDatini`.
    ///
    /// Upstream calls this from `eraDat` itself (`src/dat.c:202`) and its own
    /// header says it is for internal use only (`src/erfadatextra.h:17-22`). It
    /// is on the published route because the header publishes it, and it is
    /// here for the same reason `setLeapSeconds` is: a caller who wants to
    /// install their own table for `eraDat` has to be able to say what `eraDat`
    /// will do first, and this is the call that decides it.
    ///
    /// The rule is upstream's, and it is a test on the count rather than on
    /// `builtin`: `eraDatini` installs `builtin` only when this thread's current
    /// count is not positive (`src/erfadatextra.c:89-91`). So:
    ///
    ///   * a thread with no table yet installs `builtin`, which for a first call
    ///     is the caller's own table;
    ///   * a thread that already has a table keeps it and `builtin` is
    ///     **ignored**, so this is not a way to replace one - `setLeapSeconds`
    ///     is;
    ///   * a null `builtin` with a count of zero installs a null table, which is
    ///     the reset `setLeapSeconds(null)` performs, and after which `eraDat`
    ///     re-initialises from its own built-in table.
    ///
    /// Nothing is copied and nothing is freed: the returned slice borrows
    /// whichever storage this thread is now using, exactly as `getLeapSeconds`
    /// does, and a replacement on this thread invalidates it.
    pub fn datini(builtin: ?[]const LeapSecond) LeapTableResult {
        var table: [*c]LeapSecond = undefined;
        const builtin_count: c_int = if (builtin) |entries| @intCast(entries.len) else 0;
        const builtin_pointer: [*c]const LeapSecond = if (builtin) |entries| entries.ptr else null;
        const count = c.eraDatini(builtin_pointer, builtin_count, &table);
        const status: Status = .{ .value = count };
        // A count of zero is not an error but an empty table, and upstream's
        // pointer is null in that case, so there is nothing to borrow and
        // `entries` is absent rather than a zero-length slice over no storage.
        if (count <= 0) return .{ .status = status, .entries = null };
        const length: usize = @intCast(count);
        return .{ .status = status, .entries = table[0..length] };
    }
};

/// Calendar dates, calendar and clock times, and the encoding and decoding of
/// both into and out of the two-part Julian Date.
///
/// The calendar is proleptic Gregorian with no account taken of the adoption
/// dates and no AD/BC convention (`src/cal2jd.c:36-39`), and `cal2jd` rejects
/// years below -4799 while its algorithm is valid from -4800 March 1
/// (`src/cal2jd.c:28-29`).
pub const calendar = struct {
    /// Gregorian calendar date to the Modified Julian Date for 0 h.
    ///
    /// Upstream validates the year, then the month, then the day, and returns
    /// on the first failure. The `-3` case is the interesting one: the status
    /// reports a bad day but the Julian Date *is* computed and written
    /// (`src/cal2jd.c:68-84`), which is why `date` is not `null` for it. The
    /// algorithm needs no date conversion of its own, so there is nothing here
    /// to derive.
    pub fn cal2jd(year: i32, month: i32, day: i32) Cal2jdResult {
        var djm0: f64 = undefined;
        var djm: f64 = undefined;
        const status: Status = .{ .value = c.eraCal2jd(year, month, day, &djm0, &djm) };
        // The year and month checks return before either output is assigned
        // (cal2jd.c:68-69). The day check does not: by then both values hold a
        // computed date, so -3 keeps it (cal2jd.c:75-84).
        if (status.value == -1 or status.value == -2) {
            return .{ .status = status, .date = null };
        }
        return .{ .status = status, .date = .{ .part_a = djm0, .part_b = djm } };
    }

    /// Two-part Julian Date to a Gregorian date and a fraction of a day.
    ///
    /// The pair may be apportioned any way at all; upstream recovers the
    /// fraction with compensated summation so that the answer does not depend
    /// on the split (`src/jd2cal.c:44-46`). The accepted range is a total
    /// Julian Date from -68569.5 to 1e9 (`src/jd2cal.c:30-31`); outside it the
    /// status is `-1` and nothing is written.
    pub fn jd2cal(date: Date2) Jd2calResult {
        var iy: c_int = undefined;
        var im: c_int = undefined;
        var id: c_int = undefined;
        var fraction: f64 = undefined;
        const status: Status = .{
            .value = c.eraJd2cal(date.part_a, date.part_b, &iy, &im, &id, &fraction),
        };
        if (status.isError()) return .{ .status = status, .date = null };
        return .{
            .status = status,
            .date = .{ .year = iy, .month = im, .day = id, .fraction = fraction },
        };
    }

    /// Two-part Julian Date to a Gregorian date whose fraction of the day is
    /// rounded to `ndp` decimal places.
    ///
    /// A `ndp` outside 0-9 is not an error: upstream reads it as 0 and reports
    /// the warning `+1`, having already computed the result
    /// (`src/jdcalf.c:71-77`). A `ndp` below 4 risks overflow on a target with
    /// 16-bit `int` (`src/jdcalf.c:47-49`); this build targets none, but the
    /// bound is upstream's and is not widened here.
    pub fn jdcalf(ndp: i32, date: Date2) JdcalfResult {
        var iymdf: [4]c_int = undefined;
        const status: Status = .{
            .value = c.eraJdcalf(ndp, date.part_a, date.part_b, &iymdf),
        };
        if (status.isError()) return .{ .status = status, .date = null };
        return .{
            .status = status,
            .date = .{
                .year = iymdf[0],
                .month = iymdf[1],
                .day = iymdf[2],
                .fraction = iymdf[3],
            },
        };
    }

    /// Calendar date and clock time to a two-part Julian Date.
    ///
    /// `scale` selects the leap-second convention; upstream compares the exact
    /// upper-case string `"UTC"` and treats every other value alike
    /// (`src/dtf2d.c:39-41`). Three warnings are possible and all three leave a
    /// usable result: `+1` dubious year, `+2` the time is past the end of the
    /// day (which is how `sec > 60` is reported, and how `sec > 61` is
    /// reported on a leap-second day, `src/dtf2d.c:58-61`), and `+3` both.
    /// When `+2` or `+3` is reported the second part of `date` exceeds `1.0`,
    /// which is exactly what the module documentation says must not be
    /// normalised away.
    pub fn dtf2d(
        scale: TimeScale,
        year: i32,
        month: i32,
        day: i32,
        hour: i32,
        minute: i32,
        second: f64,
    ) Dtf2dResult {
        var part_a: f64 = undefined;
        var part_b: f64 = undefined;
        const status: Status = .{ .value = c.eraDtf2d(
            scale.code(),
            year,
            month,
            day,
            hour,
            minute,
            second,
            &part_a,
            &part_b,
        ) };
        if (status.isError()) return .{ .status = status, .date = null };
        return .{ .status = status, .date = .{ .part_a = part_a, .part_b = part_b } };
    }

    /// Two-part Julian Date to a calendar date and a clock time.
    ///
    /// `ndp` is the resolution of the seconds field and may be negative as well
    /// as positive (`src/d2dtf.c:35-48`). On a UTC leap-second day with the
    /// time at 23:59:60, `time.second` is 60; if the resolution is coarser
    /// than ten seconds, upstream advances to the next day instead
    /// (`src/d2dtf.c:163-171`). A dubious UTC year is the warning `+1`, and the
    /// result is still computed.
    pub fn d2dtf(scale: TimeScale, ndp: i32, date: Date2) D2dtfResult {
        var iy: c_int = undefined;
        var im: c_int = undefined;
        var id: c_int = undefined;
        var ihmsf: [4]c_int = undefined;
        const status: Status = .{ .value = c.eraD2dtf(
            scale.code(),
            ndp,
            date.part_a,
            date.part_b,
            &iy,
            &im,
            &id,
            &ihmsf,
        ) };
        if (status.isError()) return .{ .status = status, .date = null, .time = null };
        return .{
            .status = status,
            .date = .{ .year = iy, .month = im, .day = id },
            .time = .{
                .hour = ihmsf[0],
                .minute = ihmsf[1],
                .second = ihmsf[2],
                .fraction = ihmsf[3],
            },
        };
    }

    /// Decompose an interval in days into sign, hours, minutes, seconds and a
    /// fraction.
    ///
    /// Upstream returns no status here (`src/d2tf.c:4`), so neither does this.
    /// The absolute value of `days` may exceed `1.0`; a value very nearly `1.0`
    /// can round up to `hour == 24`, and upstream leaves handling that to the
    /// caller (`src/d2tf.c:47-50`). This module does not silently roll it over.
    pub fn d2tf(ndp: i32, days: f64) D2tfResult {
        var sign: u8 = undefined;
        var ihmsf: [4]c_int = undefined;
        c.eraD2tf(ndp, days, &sign, &ihmsf);
        return .{
            .sign = sign,
            .hour = ihmsf[0],
            .minute = ihmsf[1],
            .second = ihmsf[2],
            .fraction = ihmsf[3],
        };
    }

    /// Hours, minutes and seconds to an interval in days.
    ///
    /// A negative field produces a warning and is used by absolute value
    /// (`src/tf2d.c:32-33`), and the result is computed even when a range check
    /// fails, so `days` is present for every status. When more than one field
    /// is out of range only the first is reported (`src/tf2d.c:35-36`).
    pub fn tf2d(sign: u8, hour: i32, minute: i32, second: f64) Tf2dResult {
        var days: f64 = undefined;
        const status: Status = .{ .value = c.eraTf2d(sign, hour, minute, second, &days) };
        return .{ .status = status, .days = days };
    }

    /// Hours, minutes and seconds to an angle in radians.
    ///
    /// The status ladder and the "computed anyway" rule are as for `tf2d`.
    pub fn tf2a(sign: u8, hour: i32, minute: i32, second: f64) Tf2aResult {
        var radians: f64 = undefined;
        const status: Status = .{ .value = c.eraTf2a(sign, hour, minute, second, &radians) };
        return .{ .status = status, .radians = radians };
    }

    /// Degrees, arcminutes and arcseconds to an angle in radians.
    ///
    /// The status ladder is as for `tf2d`, with degrees bounded to 0-359 and
    /// arcminutes to 0-59 (`src/af2a.c:51-54`).
    pub fn af2a(sign: u8, degree: i32, arcminute: i32, arcsecond: f64) Af2aResult {
        var radians: f64 = undefined;
        const status: Status = .{ .value = c.eraAf2a(sign, degree, arcminute, arcsecond, &radians) };
        return .{ .status = status, .radians = radians };
    }

    /// A two-part Julian Date to a Julian Ephemeris Date in Barycentric
    /// Dynamical Time: the year plus fraction counted from 2000.0, that is
    /// `2000.0 + (days since J2000.0) / 365.25` (`src/epb.c:16-22`).
    pub fn epb(date: Date2) f64 {
        return c.eraEpb(date.part_a, date.part_b);
    }

    /// A Julian Ephemeris Date to a two-part Julian Date.
    ///
    /// Upstream returns no status here (`src/epb2jd.c`), so neither does this.
    /// The split it produces is the MJD convention: `part_a` is always
    /// `ERFA_DJM0` and `part_b` is the MJD, which is the shape that preserves
    /// time resolution.
    pub fn epb2jd(epoch: f64) Date2 {
        var djm0: f64 = undefined;
        var djm: f64 = undefined;
        c.eraEpb2jd(epoch, &djm0, &djm);
        return .{ .part_a = djm0, .part_b = djm };
    }

    /// A two-part Julian Date to a Julian Ephemeris Date in TDB: the year plus
    /// fraction counted from 2000.0 (`src/epj.c:53`).
    pub fn epj(date: Date2) f64 {
        return c.eraEpj(date.part_a, date.part_b);
    }

    /// A Julian Ephemeris Date in TDB to a two-part Julian Date.
    pub fn epj2jd(epoch: f64) Date2 {
        var djm0: f64 = undefined;
        var djm: f64 = undefined;
        c.eraEpj2jd(epoch, &djm0, &djm);
        return .{ .part_a = djm0, .part_b = djm };
    }
};

/// Conversions between the astronomical time scales, and the leap-second
/// offset TAI-UTC itself.
///
/// Every conversion here returns a `DateResult`, so the status survives even
/// when upstream always returns zero. `eraUtcut1` shows why that matters: it
/// keeps a child's positive status and collapses any negative child to `-1`
/// (`src/utcut1.c:86-90`), so a warning's *value* can change along a chain and
/// only carrying the integer preserves what happened.
pub const timescale = struct {
    /// TAI minus UTC in seconds for a given UTC date.
    ///
    /// `+1` is the dubious-year warning, and it is reported for two quite
    /// different situations: a date before UTC began in 1960, where the result
    /// is *not* computed and is `0.0` (`src/dat.c:65-67`, `:222`), and a year
    /// more than five past this release's `IYV` of 2023, where the result *is*
    /// computed in the normal way (`src/dat.c:71-74`, `:225`). The same
    /// warning therefore covers a missing result and a doubtful one; the
    /// status alone does not distinguish them, and the zero delta is the only
    /// way to tell. From 2029 onwards every call returns `+1`.
    ///
    /// With several errors, the first detected is the one reported
    /// (`src/dat.c:99-104`). `delta_at` is `0.0` whenever no valid result is
    /// available (`src/dat.c:106`).
    pub fn dat(year: i32, month: i32, day: i32, fraction_of_day: f64) DatResult {
        var delta: f64 = undefined;
        const status: Status = .{ .value = c.eraDat(year, month, day, fraction_of_day, &delta) };
        return .{ .status = status, .delta_at = delta };
    }

    /// TAI to UTC.
    ///
    /// The UTC result is a quasi-JD whose day may be 86399, 86400 or 86401 SI
    /// seconds long (`src/taiutc.c:32-38`). On any negative status the outputs
    /// are absent: upstream returns before writing them
    /// (`src/taiutc.c:88-89`).
    pub fn taiutc(date: Date2) DateResult {
        var utc1: f64 = undefined;
        var utc2: f64 = undefined;
        const status: Status = .{ .value = c.eraTaiutc(date.part_a, date.part_b, &utc1, &utc2) };
        if (status.isError()) return .{ .status = status, .date = null };
        return .{ .status = status, .date = .{ .part_a = utc1, .part_b = utc2 } };
    }

    /// UTC to TAI.
    ///
    /// `+1` is the dubious-year warning from `dat` propagated out of the UTC
    /// leap-second handling. On any negative status the outputs are absent.
    pub fn utctai(date: Date2) DateResult {
        var tai1: f64 = undefined;
        var tai2: f64 = undefined;
        const status: Status = .{ .value = c.eraUtctai(date.part_a, date.part_b, &tai1, &tai2) };
        if (status.isError()) return .{ .status = status, .date = null };
        return .{ .status = status, .date = .{ .part_a = tai1, .part_b = tai2 } };
    }

    /// UTC to UT1, given UT1-UTC in seconds.
    ///
    /// The UT1-UTC value is an observed quantity the caller must supply to
    /// match the date (`src/utcut1.c:45-47`). The `+1` dubious-year warning is
    /// copied out of `eraUtctai`; any negative status there becomes `-1` here
    /// and leaves the outputs absent (`src/utcut1.c:85-91`).
    pub fn utcut1(date: Date2, delta_ut1: f64) DateResult {
        var ut11: f64 = undefined;
        var ut12: f64 = undefined;
        const status: Status = .{
            .value = c.eraUtcut1(date.part_a, date.part_b, delta_ut1, &ut11, &ut12),
        };
        if (status.isError()) return .{ .status = status, .date = null };
        return .{ .status = status, .date = .{ .part_a = ut11, .part_b = ut12 } };
    }

    /// UT1 to UTC, given UT1-UTC in seconds.
    ///
    /// Near a leap second the algorithm is deliberately tolerant of the
    /// "wrong" choice of UT1-UTC (`src/ut1utc.c:36-38`). On a negative status
    /// the outputs are absent (`src/ut1utc.c:95-96`).
    pub fn ut1utc(date: Date2, delta_ut1: f64) DateResult {
        var utc1: f64 = undefined;
        var utc2: f64 = undefined;
        const status: Status = .{
            .value = c.eraUt1utc(date.part_a, date.part_b, delta_ut1, &utc1, &utc2),
        };
        if (status.isError()) return .{ .status = status, .date = null };
        return .{ .status = status, .date = .{ .part_a = utc1, .part_b = utc2 } };
    }

    /// UT1 to TAI, given UT1-TAI in seconds.
    pub fn ut1tai(date: Date2, delta_tai: f64) DateResult {
        var tai1: f64 = undefined;
        var tai2: f64 = undefined;
        const status: Status = .{
            .value = c.eraUt1tai(date.part_a, date.part_b, delta_tai, &tai1, &tai2),
        };
        return .{ .status = status, .date = .{ .part_a = tai1, .part_b = tai2 } };
    }

    /// TAI to UT1, given UT1-TAI in seconds.
    pub fn taiut1(date: Date2, delta_tai: f64) DateResult {
        var ut11: f64 = undefined;
        var ut12: f64 = undefined;
        const status: Status = .{
            .value = c.eraTaiut1(date.part_a, date.part_b, delta_tai, &ut11, &ut12),
        };
        return .{ .status = status, .date = .{ .part_a = ut11, .part_b = ut12 } };
    }

    /// UT1 to TT, given TT-UT1 in seconds, which is classical Delta T.
    pub fn ut1tt(date: Date2, delta_t: f64) DateResult {
        var tt1: f64 = undefined;
        var tt2: f64 = undefined;
        const status: Status = .{ .value = c.eraUt1tt(date.part_a, date.part_b, delta_t, &tt1, &tt2) };
        return .{ .status = status, .date = .{ .part_a = tt1, .part_b = tt2 } };
    }

    /// TT to UT1, given TT-UT1 in seconds.
    pub fn ttut1(date: Date2, delta_t: f64) DateResult {
        var ut11: f64 = undefined;
        var ut12: f64 = undefined;
        const status: Status = .{ .value = c.eraTtut1(date.part_a, date.part_b, delta_t, &ut11, &ut12) };
        return .{ .status = status, .date = .{ .part_a = ut11, .part_b = ut12 } };
    }

    /// TAI to TT, by the fixed 32.184 s the two scales are defined to differ
    /// by (`src/taitt.c:44-45`).
    pub fn taitt(date: Date2) DateResult {
        var tt1: f64 = undefined;
        var tt2: f64 = undefined;
        const status: Status = .{ .value = c.eraTaitt(date.part_a, date.part_b, &tt1, &tt2) };
        return .{ .status = status, .date = .{ .part_a = tt1, .part_b = tt2 } };
    }

    /// TT to TAI, by the same fixed 32.184 s.
    pub fn tttai(date: Date2) DateResult {
        var tai1: f64 = undefined;
        var tai2: f64 = undefined;
        const status: Status = .{ .value = c.eraTttai(date.part_a, date.part_b, &tai1, &tai2) };
        return .{ .status = status, .date = .{ .part_a = tai1, .part_b = tai2 } };
    }

    /// TCG to TT, by the rate difference the IAU 2000 Resolution B1.9 fixes
    /// (`src/tcgtt.c:43-44`).
    pub fn tcgtt(date: Date2) DateResult {
        var tt1: f64 = undefined;
        var tt2: f64 = undefined;
        const status: Status = .{ .value = c.eraTcgtt(date.part_a, date.part_b, &tt1, &tt2) };
        return .{ .status = status, .date = .{ .part_a = tt1, .part_b = tt2 } };
    }

    /// TT to TCG.
    pub fn tttcg(date: Date2) DateResult {
        var tcg1: f64 = undefined;
        var tcg2: f64 = undefined;
        const status: Status = .{ .value = c.eraTttcg(date.part_a, date.part_b, &tcg1, &tcg2) };
        return .{ .status = status, .date = .{ .part_a = tcg1, .part_b = tcg2 } };
    }

    /// TCB to TDB, by the conventional linear relation the 2006 IAU General
    /// Assembly introduced (`src/tcbtdb.c:29-42`).
    pub fn tcbtdb(date: Date2) DateResult {
        var tdb1: f64 = undefined;
        var tdb2: f64 = undefined;
        const status: Status = .{ .value = c.eraTcbtdb(date.part_a, date.part_b, &tdb1, &tdb2) };
        return .{ .status = status, .date = .{ .part_a = tdb1, .part_b = tdb2 } };
    }

    /// TDB to TCB.
    pub fn tdbtcb(date: Date2) DateResult {
        var tcb1: f64 = undefined;
        var tcb2: f64 = undefined;
        const status: Status = .{ .value = c.eraTdbtcb(date.part_a, date.part_b, &tcb1, &tcb2) };
        return .{ .status = status, .date = .{ .part_a = tcb1, .part_b = tcb2 } };
    }

    /// TDB to TT, given TDB-TT in seconds; the argument is the quasi-periodic
    /// term of the GR transformation and is dominated by an annual 1.7 ms
    /// amplitude (`src/tdbtt.c:31-37`).
    pub fn tdbtt(date: Date2, delta_tdb: f64) DateResult {
        var tt1: f64 = undefined;
        var tt2: f64 = undefined;
        const status: Status = .{
            .value = c.eraTdbtt(date.part_a, date.part_b, delta_tdb, &tt1, &tt2),
        };
        return .{ .status = status, .date = .{ .part_a = tt1, .part_b = tt2 } };
    }

    /// TT to TDB, given TDB-TT in seconds; the argument is the same
    /// quasi-periodic term `tdbtt` takes.
    pub fn tttdb(date: Date2, delta_tdb: f64) DateResult {
        var tdb1: f64 = undefined;
        var tdb2: f64 = undefined;
        const status: Status = .{
            .value = c.eraTttdb(date.part_a, date.part_b, delta_tdb, &tdb1, &tdb2),
        };
        return .{ .status = status, .date = .{ .part_a = tdb1, .part_b = tdb2 } };
    }

    /// TDB minus TT in seconds for an observer on the Earth, `eraDtdb`.
    ///
    /// This is the difference `tdbtt` and `tttdb` take as an argument, so the
    /// pair here closes the loop: `tttdb(date, dtdb(...))` and `tdbtt(date,
    /// dtdb(...))` are the same conversion stated in two steps.
    ///
    /// Unlike every other routine in this namespace it takes no two-part date
    /// alone and returns no status. The four extra arguments are the observer's
    /// state and are upstream's own, unchanged (`src/dtdb.c:44-48`):
    ///
    ///   * `ut1_fraction` is universal time UT1 as a fraction of one day;
    ///   * `longitude` is east positive, radians;
    ///   * `distance_from_axis_km` is the observer's distance from the Earth's
    ///     spin axis in kilometres;
    ///   * `distance_north_of_equator_km` is the observer's distance north of
    ///     the equatorial plane in kilometres.
    ///
    /// `date` is a TDB two-part Julian Date. The model is an approximation of
    /// the "periodic" terms of the TDB-TT relation, tabulated in upstream's own
    /// source rather than read from data (`src/dtdb.c`), and upstream says so:
    /// a result of a couple of milliseconds is the expected accuracy, not a
    /// microsecond-level answer.
    pub fn dtdb(
        date: Date2,
        ut1_fraction: f64,
        longitude: f64,
        distance_from_axis_km: f64,
        distance_north_of_equator_km: f64,
    ) f64 {
        return c.eraDtdb(
            date.part_a,
            date.part_b,
            ut1_fraction,
            longitude,
            distance_from_axis_km,
            distance_north_of_equator_km,
        );
    }
};

/// The Earth-rotation quantities: the Earth rotation angle, the Greenwich
/// mean and apparent sidereal times of each model, and the astrometry and
/// observed-place transformations that consume them.
///
/// The sidereal-time routines return no status upstream, so neither do they
/// here; they also all return an angle normalised into `[0, 2*pi)`
/// (`src/era00.c:18`, `src/gmst00.c:53-54`). The `ap*13`/`at*13` family does
/// return a status and the `+1` dubious-year warning is carried through.
pub const rotation = struct {
    /// The Earth rotation angle, IAU 2000 model, radians in `[0, 2*pi)`.
    ///
    /// `date` is a UT1 two-part Julian Date. Maximum precision comes from the
    /// date-and-time split, where one part is 0 h UT1 on the day and the other
    /// lies in `[0, 1]` (`src/era00.c:33-40`).
    pub fn earthRotationAngle(date: Date2) f64 {
        return c.eraEra00(date.part_a, date.part_b);
    }

    /// Greenwich mean sidereal time, IAU 2000 resolutions, radians.
    ///
    /// Both UT1 and TT are required: UT1 predicts the Earth rotation and TT
    /// predicts precession, and using UT1 for both costs about 100
    /// microarcseconds (`src/gmst00.c:45-48`). This GMST is compatible only
    /// with IAU 2000 compatible precession-nutation and equation of the
    /// equinoxes (`src/gmst00.c:49-52`).
    pub fn gmst00(ut1: Date2, tt: Date2) f64 {
        return c.eraGmst00(ut1.part_a, ut1.part_b, tt.part_a, tt.part_b);
    }

    /// Greenwich mean sidereal time, IAU 2006 model, radians.
    pub fn gmst06(ut1: Date2, tt: Date2) f64 {
        return c.eraGmst06(ut1.part_a, ut1.part_b, tt.part_a, tt.part_b);
    }

    /// Greenwich mean sidereal time, IAU 1982 model, radians.
    ///
    /// This model predates the IAU 2000 resolutions and is not compatible with
    /// the `gmst00` family.
    pub fn gmst82(date: Date2) f64 {
        return c.eraGmst82(date.part_a, date.part_b);
    }

    /// Greenwich apparent sidereal time, IAU 2000A model, radians.
    pub fn gst00a(ut1: Date2, tt: Date2) f64 {
        return c.eraGst00a(ut1.part_a, ut1.part_b, tt.part_a, tt.part_b);
    }

    /// Greenwich apparent sidereal time, IAU 2000B model, radians.
    pub fn gst00b(ut1: Date2) f64 {
        return c.eraGst00b(ut1.part_a, ut1.part_b);
    }

    /// Greenwich apparent sidereal time, IAU 2006 model, radians.
    pub fn gst06a(ut1: Date2, tt: Date2) f64 {
        return c.eraGst06a(ut1.part_a, ut1.part_b, tt.part_a, tt.part_b);
    }

    /// Greenwich apparent sidereal time, IAU 1994 model, radians.
    pub fn gst94(ut1: Date2) f64 {
        return c.eraGst94(ut1.part_a, ut1.part_b);
    }

    /// Greenwich apparent sidereal time, IAU 2006 model, radians.
    ///
    /// Unlike `gst06a`, the caller supplies the bias-precession-nutation matrix
    /// and thus chooses its nutation model. Both routines form the equation of
    /// the origins; `gst06a` builds its matrix with `eraPnm06a` first.
    /// `rnpb` is only read (`src/gst06.c`, `src/gst06a.c`).
    pub fn gst06(ut1: Date2, tt: Date2, rnpb: *const Mat3) f64 {
        return c.eraGst06(ut1.part_a, ut1.part_b, tt.part_a, tt.part_b, @constCast(rnpb));
    }

    /// Equation of the equinoxes from a mean obliquity and a nutation angle,
    /// radians.
    pub fn ee00(date: Date2, mean_obliquity: f64, dpsi: f64) f64 {
        return c.eraEe00(date.part_a, date.part_b, mean_obliquity, dpsi);
    }

    /// Equation of the equinoxes, IAU 2000A model, radians.
    pub fn ee00a(date: Date2) f64 {
        return c.eraEe00a(date.part_a, date.part_b);
    }

    /// Equation of the equinoxes, IAU 2000B model, radians.
    pub fn ee00b(date: Date2) f64 {
        return c.eraEe00b(date.part_a, date.part_b);
    }

    /// Equation of the equinoxes, IAU 2006 model, radians.
    pub fn ee06a(date: Date2) f64 {
        return c.eraEe06a(date.part_a, date.part_b);
    }

    /// Equation of the equinoxes including the complementary terms, IAU 2000A
    /// model, radians.
    pub fn eect00(date: Date2) f64 {
        return c.eraEect00(date.part_a, date.part_b);
    }

    /// Prepare star-independent astrometry parameters for transformations
    /// between ICRS and observed coordinates, plus the equation of the
    /// origins.
    ///
    /// `date` is a UTC two-part quasi-JD and `site` carries UT1-UTC, the site
    /// coordinates, the ambient conditions and the observing wavelength.
    /// Upstream performs no validation of these beyond the date it must decode
    /// (`src/apco13.c` note 8), so this module does not invent bounds for them
    /// either; it only says where they go.
    pub fn apco13(date: Date2, site: Observatory) Apco13Result {
        var astrom: c.eraASTROM = undefined;
        var eo: f64 = undefined;
        const status: Status = .{ .value = c.eraApco13(
            date.part_a,
            date.part_b,
            site.delta_ut1,
            site.longitude,
            site.latitude,
            site.height,
            site.polar_motion_x,
            site.polar_motion_y,
            site.pressure,
            site.temperature,
            site.humidity,
            site.wavelength,
            &astrom,
            &eo,
        ) };
        if (status.isError()) return .{ .status = status, .astrom = null, .equation_of_origins = null };
        return .{ .status = status, .astrom = astromOf(astrom), .equation_of_origins = eo };
    }

    /// Prepare star-independent astrometry parameters for transformations
    /// between CIRS and observed coordinates.
    ///
    /// This is not `apco13` without the last step. `eraApio13` calls
    /// `eraApio`, which computes the CIRS-observed parameters alone
    /// (`src/apio13.c:192-193`, `src/apio.c:140-166`), so `pmt`, `eb`, `eh`,
    /// `em`, `v`, `bm1` and `bpn` are not produced and are not in
    /// `Apio13Result`. Upstream writes those into a record the caller already
    /// holds, which is what lets `eraAtciq` consume it afterwards
    /// (`src/atciq.c:75-84`); this module has no such record to hand on, so it
    /// returns the members that exist. The two results share the nine
    /// `ObservedAstrom` members.
    pub fn apio13(date: Date2, site: Observatory) Apio13Result {
        var astrom: c.eraASTROM = undefined;
        const status: Status = .{ .value = c.eraApio13(
            date.part_a,
            date.part_b,
            site.delta_ut1,
            site.longitude,
            site.latitude,
            site.height,
            site.polar_motion_x,
            site.polar_motion_y,
            site.pressure,
            site.temperature,
            site.humidity,
            site.wavelength,
            &astrom,
        ) };
        if (status.isError()) return .{ .status = status, .astrom = null };
        return .{ .status = status, .astrom = observedAstromOf(astrom) };
    }

    /// ICRS astrometric right ascension and declination to observed azimuth,
    /// zenith distance, hour angle, declination and right ascension, plus the
    /// equation of the origins, ERA minus GST, in radians.
    ///
    /// The star's proper motion is per Julian year and its parallax is in
    /// arcseconds (`src/atco13.c`), which is the mix most catalogues are stored
    /// in; no unit conversion is done here.
    pub fn atco13(
        icrs: ObservedSpherical,
        proper_motion: ObservedSpherical,
        parallax: f64,
        radial_velocity: f64,
        date: Date2,
        site: Observatory,
    ) Atco13Result {
        var aob: f64 = undefined;
        var zob: f64 = undefined;
        var hob: f64 = undefined;
        var dob: f64 = undefined;
        var rob: f64 = undefined;
        var eo: f64 = undefined;
        const status: Status = .{ .value = c.eraAtco13(
            icrs.first,
            icrs.second,
            proper_motion.first,
            proper_motion.second,
            parallax,
            radial_velocity,
            date.part_a,
            date.part_b,
            site.delta_ut1,
            site.longitude,
            site.latitude,
            site.height,
            site.polar_motion_x,
            site.polar_motion_y,
            site.pressure,
            site.temperature,
            site.humidity,
            site.wavelength,
            &aob,
            &zob,
            &hob,
            &dob,
            &rob,
            &eo,
        ) };
        if (status.isError()) return .{ .status = status, .place = null, .equation_of_origins = null };
        return .{
            .status = status,
            .place = .{
                .azimuth = aob,
                .zenith_distance = zob,
                .hour_angle = hob,
                .declination = dob,
                .right_ascension = rob,
            },
            .equation_of_origins = eo,
        };
    }

    /// CIRS right ascension and declination to observed azimuth, zenith
    /// distance, hour angle, declination and right ascension.
    pub fn atio13(date: Date2, site: Observatory, cirs: ObservedSpherical) Atio13Result {
        var aob: f64 = undefined;
        var zob: f64 = undefined;
        var hob: f64 = undefined;
        var dob: f64 = undefined;
        var rob: f64 = undefined;
        const status: Status = .{ .value = c.eraAtio13(
            cirs.first,
            cirs.second,
            date.part_a,
            date.part_b,
            site.delta_ut1,
            site.longitude,
            site.latitude,
            site.height,
            site.polar_motion_x,
            site.polar_motion_y,
            site.pressure,
            site.temperature,
            site.humidity,
            site.wavelength,
            &aob,
            &zob,
            &hob,
            &dob,
            &rob,
        ) };
        if (status.isError()) return .{ .status = status, .place = null };
        return .{
            .status = status,
            .place = .{
                .azimuth = aob,
                .zenith_distance = zob,
                .hour_angle = hob,
                .declination = dob,
                .right_ascension = rob,
            },
        };
    }

    /// Observed azimuth and zenith distance, or hour angle and declination, at
    /// a ground-based site to ICRS astrometric right ascension and
    /// declination.
    ///
    /// `observed.first` and `observed.second` are interpreted according to
    /// `kind`; for `.azimuth` they are azimuth (north zero, east 90 degrees)
    /// and zenith distance (`src/atoc13.c:41-45`).
    pub fn atoc13(
        kind: ObservationType,
        observed: ObservedSpherical,
        date: Date2,
        site: Observatory,
    ) Atoc13Result {
        var rc: f64 = undefined;
        var dc: f64 = undefined;
        const status: Status = .{ .value = c.eraAtoc13(
            kind.code(),
            observed.first,
            observed.second,
            date.part_a,
            date.part_b,
            site.delta_ut1,
            site.longitude,
            site.latitude,
            site.height,
            site.polar_motion_x,
            site.polar_motion_y,
            site.pressure,
            site.temperature,
            site.humidity,
            site.wavelength,
            &rc,
            &dc,
        ) };
        if (status.isError()) return .{ .status = status, .icrs = null };
        return .{ .status = status, .icrs = .{ .first = rc, .second = dc } };
    }

    /// Observed azimuth and zenith distance, or hour angle and declination, at
    /// a ground-based site to CIRS right ascension and declination.
    pub fn atoi13(
        kind: ObservationType,
        observed: ObservedSpherical,
        date: Date2,
        site: Observatory,
    ) Atoi13Result {
        var ri: f64 = undefined;
        var di: f64 = undefined;
        const status: Status = .{ .value = c.eraAtoi13(
            kind.code(),
            observed.first,
            observed.second,
            date.part_a,
            date.part_b,
            site.delta_ut1,
            site.longitude,
            site.latitude,
            site.height,
            site.polar_motion_x,
            site.polar_motion_y,
            site.pressure,
            site.temperature,
            site.humidity,
            site.wavelength,
            &ri,
            &di,
        ) };
        if (status.isError()) return .{ .status = status, .cirs = null };
        return .{ .status = status, .cirs = .{ .first = ri, .second = di } };
    }
};

/// Geodetic and geocentric coordinates, and the reference ellipsoids they are
/// expressed on.
///
/// Two things here are easy to get wrong and are preserved rather than
/// tidied. Upstream validates no coordinate arguments at all
/// (`src/gd2gc.c:45-50`, `src/gc2gd.c` note 2), and its error results are
/// sentinels rather than absences: `-1e9` in all three geodetic fields
/// (`src/gc2gd.c:75-79`) and zeros in the Cartesian vector
/// (`src/gd2gc.c:78`). A caller that treats `-1e9` as data is doing what
/// upstream permits; this module says so instead of hiding it.
pub const geodetic = struct {
    /// The equatorial radius and flattening of a reference ellipsoid.
    ///
    /// `equatorial_radius` and `flattening` are always present and are
    /// exactly `0.0` on the illegal-identifier status (`src/eform.c:86-89`).
    /// This function is the only way to turn an `Ellipsoid` into numbers.
    pub fn eform(ellipsoid: Ellipsoid) EformResult {
        var equatorial_radius: f64 = undefined;
        var flattening: f64 = undefined;
        const status: Status = .{ .value = c.eraEform(ellipsoid.id(), &equatorial_radius, &flattening) };
        return .{
            .status = status,
            .equatorial_radius = equatorial_radius,
            .flattening = flattening,
        };
    }

    /// Geocentric Cartesian coordinates to geodetic longitude, latitude and
    /// height on a named reference ellipsoid.
    ///
    /// `cartesian` is in metres for a terrestrial ellipsoid and is not
    /// modified. `geodetic` is present for every status, carrying the `-1e9`
    /// sentinel on error.
    pub fn gc2gd(ellipsoid: Ellipsoid, cartesian: *const Vec3) Gc2gdResult {
        var longitude: f64 = undefined;
        var latitude: f64 = undefined;
        var height: f64 = undefined;
        const status: Status = .{ .value = c.eraGc2gd(
            ellipsoid.id(),
            @constCast(cartesian),
            &longitude,
            &latitude,
            &height,
        ) };
        return .{
            .status = status,
            .geodetic = .{ .longitude = longitude, .latitude = latitude, .height = height },
        };
    }

    /// Geocentric Cartesian coordinates to geodetic coordinates on an
    /// ellipsoid of stated radius and flattening.
    ///
    /// The `-1` and `-2` statuses are an out-of-range flattening and a
    /// non-positive radius (`src/gc2gde.c:76-77`), and on either the outputs
    /// are left untouched upstream (`src/gc2gde.c:44-46`), which is why
    /// `geodetic` is `null` there rather than a sentinel.
    pub fn gc2gde(equatorial_radius: f64, flattening: f64, cartesian: *const Vec3) Gc2gdeResult {
        var longitude: f64 = undefined;
        var latitude: f64 = undefined;
        var height: f64 = undefined;
        const status: Status = .{ .value = c.eraGc2gde(
            equatorial_radius,
            flattening,
            @constCast(cartesian),
            &longitude,
            &latitude,
            &height,
        ) };
        if (status.isError()) return .{ .status = status, .geodetic = null };
        return .{
            .status = status,
            .geodetic = .{ .longitude = longitude, .latitude = latitude, .height = height },
        };
    }

    /// Geodetic longitude, latitude and height to geocentric Cartesian
    /// coordinates on a named reference ellipsoid.
    ///
    /// No validation is performed on the three arguments upstream, by design
    /// (`src/gd2gc.c:45-50`). `cartesian` is present for every status and is
    /// all zeros on error.
    pub fn gd2gc(ellipsoid: Ellipsoid, geodetic_position: Geodetic) Gd2gcResult {
        var cartesian: Vec3 = undefined;
        const status: Status = .{ .value = c.eraGd2gc(
            ellipsoid.id(),
            geodetic_position.longitude,
            geodetic_position.latitude,
            geodetic_position.height,
            &cartesian,
        ) };
        return .{ .status = status, .cartesian = cartesian };
    }

    /// Geodetic longitude, latitude and height to geocentric Cartesian
    /// coordinates on an ellipsoid of stated radius and flattening.
    ///
    /// The `-1` status protects against arguments that would make a divisor
    /// non-positive, not against unrealistic coordinates
    /// (`src/gd2gce.c:39-42`); on it the output is left untouched upstream, so
    /// `cartesian` is `null`.
    pub fn gd2gce(equatorial_radius: f64, flattening: f64, position: Geodetic) Gd2gceResult {
        var cartesian: Vec3 = undefined;
        const status: Status = .{ .value = c.eraGd2gce(
            equatorial_radius,
            flattening,
            position.longitude,
            position.latitude,
            position.height,
            &cartesian,
        ) };
        if (status.isError()) return .{ .status = status, .cartesian = null };
        return .{ .status = status, .cartesian = cartesian };
    }
};

/// The observing site and conditions the astrometry routines take.
///
/// These are grouped because upstream takes them as one long positional
/// argument list in five routines with the same order
/// (`src/apco13.c:4-7`, `src/apio13.c:4-7`, `src/atco13.c:4-10`,
/// `src/atio13.c:4-9`, `src/atoc13.c:4-8`, `src/atoi13.c:4-8`). Upstream
/// validates none of them beyond the date it has to decode, so this module
/// documents them and does not invent ranges.
pub const Observatory = struct {
    /// UT1 minus UTC in seconds, an observed quantity the caller must match to
    /// the date.
    delta_ut1: f64,
    /// Longitude, radians, east positive.
    longitude: f64,
    /// Geodetic latitude, radians.
    latitude: f64,
    /// Height above the ellipsoid, metres, geodetic.
    height: f64,
    /// Polar motion x coordinate, radians.
    polar_motion_x: f64,
    /// Polar motion y coordinate, radians.
    polar_motion_y: f64,
    /// Atmospheric pressure at the observer, hPa.
    pressure: f64,
    /// Ambient temperature at the observer, degrees Celsius.
    temperature: f64,
    /// Relative humidity at the observer, 0 to 1.
    humidity: f64,
    /// Observing wavelength, micrometers. The air-to-vacuum transition is
    /// assumed at 0.55 um.
    wavelength: f64,
};

/// A pair of equatorial coordinates, radians.
pub const EquatorialCoordinates = struct {
    /// Right ascension.
    right_ascension: f64,
    /// Declination.
    declination: f64,
};

/// A pair of ecliptic coordinates, radians.
pub const EclipticCoordinates = struct {
    /// Ecliptic longitude.
    longitude: f64,
    /// Ecliptic latitude.
    latitude: f64,
};

/// Obliquity, nutation, precession and the rotations built from them.
///
/// None of these routines returns a status upstream, so none does here; the
/// names carry the model each one implements, because mixing models is the
/// usual way a caller gets an answer that is subtly wrong. Every rotation
/// matrix is written in full by upstream, so each wrapper returns a complete
/// `Mat3` by value rather than a caller buffer.
pub const precession = struct {
    /// Mean obliquity of the ecliptic, IAU 2006 model, radians.
    pub fn obl06(date: Date2) f64 {
        return c.eraObl06(date.part_a, date.part_b);
    }

    /// Mean obliquity of the ecliptic, IAU 1980 model, radians.
    pub fn obl80(date: Date2) f64 {
        return c.eraObl80(date.part_a, date.part_b);
    }

    /// Equation of the equinoxes, IAU 1994 model, radians.
    pub fn eqeq94(date: Date2) f64 {
        return c.eraEqeq94(date.part_a, date.part_b);
    }

    /// Equation of the origins, IAU 2006 model, radians: ERA - GST, which is
    /// not the equation of the equinoxes (`src/eo06a.c`).
    pub fn eo06a(date: Date2) f64 {
        return c.eraEo06a(date.part_a, date.part_b);
    }

    /// The equation of the origins implied by a bias-precession-nutation matrix
    /// and the CIO locator `s`, radians.
    ///
    /// `cio_locator_s` is the celestial intermediate origin locator in
    /// **radians**, not an arcsecond scale factor, and the result is the
    /// equation of the origins, ERA - GST, which carries the precession
    /// contribution and is a different quantity from the equation of the
    /// equinoxes (`src/eors.c:14-27`). `rnpb` is only read (`src/eors.c`), so
    /// this wrapper takes it as `const`.
    pub fn eors(rnpb: *const Mat3, cio_locator_s: f64) f64 {
        return c.eraEors(@constCast(rnpb), cio_locator_s);
    }

    /// The CIP X and Y coordinates implied by four Fukushima-Williams angles,
    /// radians.
    pub fn fw2xy(gamma_bar: f64, phi_bar: f64, psi: f64, epsilon: f64) Cip {
        var x: f64 = undefined;
        var y: f64 = undefined;
        c.eraFw2xy(gamma_bar, phi_bar, psi, epsilon, &x, &y);
        return .{ .x = x, .y = y };
    }

    /// The rotation matrix implied by four Fukushima-Williams angles.
    pub fn fw2m(gamma_bar: f64, phi_bar: f64, psi: f64, epsilon: f64) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraFw2m(gamma_bar, phi_bar, psi, epsilon, &matrix);
        return matrix;
    }

    /// The three IAU 1976 precession angles taking the catalog epoch to the
    /// date, radians.
    pub fn prec76(from: Date2, to: Date2) Prec76Angles {
        var zeta: f64 = undefined;
        var z: f64 = undefined;
        var theta: f64 = undefined;
        c.eraPrec76(from.part_a, from.part_b, to.part_a, to.part_b, &zeta, &z, &theta);
        return .{ .zeta = zeta, .z = z, .theta = theta };
    }

    /// Nutation in longitude and obliquity, IAU 2000A model, radians.
    pub fn nut00a(date: Date2) Nutation {
        var dpsi: f64 = undefined;
        var deps: f64 = undefined;
        c.eraNut00a(date.part_a, date.part_b, &dpsi, &deps);
        return .{ .dpsi = dpsi, .deps = deps };
    }

    /// Nutation in longitude and obliquity, IAU 2000B model, radians.
    pub fn nut00b(date: Date2) Nutation {
        var dpsi: f64 = undefined;
        var deps: f64 = undefined;
        c.eraNut00b(date.part_a, date.part_b, &dpsi, &deps);
        return .{ .dpsi = dpsi, .deps = deps };
    }

    /// Nutation in longitude and obliquity, IAU 2006 model, radians.
    pub fn nut06a(date: Date2) Nutation {
        var dpsi: f64 = undefined;
        var deps: f64 = undefined;
        c.eraNut06a(date.part_a, date.part_b, &dpsi, &deps);
        return .{ .dpsi = dpsi, .deps = deps };
    }

    /// Nutation in longitude and obliquity, IAU 1980 model, radians.
    pub fn nut80(date: Date2) Nutation {
        var dpsi: f64 = undefined;
        var deps: f64 = undefined;
        c.eraNut80(date.part_a, date.part_b, &dpsi, &deps);
        return .{ .dpsi = dpsi, .deps = deps };
    }

    /// The nutation rotation matrix, IAU 2000 model.
    pub fn num00a(date: Date2) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraNum00a(date.part_a, date.part_b, &matrix);
        return matrix;
    }

    /// The nutation rotation matrix, IAU 2000B model.
    pub fn num00b(date: Date2) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraNum00b(date.part_a, date.part_b, &matrix);
        return matrix;
    }

    /// The nutation rotation matrix, IAU 2006 model.
    pub fn num06a(date: Date2) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraNum06a(date.part_a, date.part_b, &matrix);
        return matrix;
    }

    /// The nutation rotation matrix, IAU 1980 model.
    pub fn nutm80(date: Date2) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraNutm80(date.part_a, date.part_b, &matrix);
        return matrix;
    }

    /// Precession-nutation, IAU 2000 model, from a supplied pair of nutation
    /// angles.
    ///
    /// `dpsi` and `deps` come back unchanged, because they are the model's
    /// inputs rather than its output; use `nut00a` or `nut00b` to compute them.
    pub fn pn00(date: Date2, dpsi: f64, deps: f64) PrecessionNutation {
        var result: PrecessionNutation = undefined;
        c.eraPn00(
            date.part_a,
            date.part_b,
            dpsi,
            deps,
            &result.epsa,
            &result.rb,
            &result.rp,
            &result.rbp,
            &result.rn,
            &result.rbpn,
        );
        result.dpsi = dpsi;
        result.deps = deps;
        return result;
    }

    /// Precession-nutation, IAU 2006 model, from a supplied pair of nutation
    /// angles, returned unchanged.
    pub fn pn06(date: Date2, dpsi: f64, deps: f64) PrecessionNutation {
        var result: PrecessionNutation = undefined;
        c.eraPn06(
            date.part_a,
            date.part_b,
            dpsi,
            deps,
            &result.epsa,
            &result.rb,
            &result.rp,
            &result.rbp,
            &result.rn,
            &result.rbpn,
        );
        result.dpsi = dpsi;
        result.deps = deps;
        return result;
    }

    /// Precession-nutation, IAU 2000A model, computing the nutation angles.
    pub fn pn00a(date: Date2) PrecessionNutation {
        var result: PrecessionNutation = undefined;
        c.eraPn00a(
            date.part_a,
            date.part_b,
            &result.dpsi,
            &result.deps,
            &result.epsa,
            &result.rb,
            &result.rp,
            &result.rbp,
            &result.rn,
            &result.rbpn,
        );
        return result;
    }

    /// Precession-nutation, IAU 2000B model, computing the nutation angles.
    pub fn pn00b(date: Date2) PrecessionNutation {
        var result: PrecessionNutation = undefined;
        c.eraPn00b(
            date.part_a,
            date.part_b,
            &result.dpsi,
            &result.deps,
            &result.epsa,
            &result.rb,
            &result.rp,
            &result.rbp,
            &result.rn,
            &result.rbpn,
        );
        return result;
    }

    /// Precession-nutation, IAU 2006/2000A models, computing the nutation
    /// angles.
    pub fn pn06a(date: Date2) PrecessionNutation {
        var result: PrecessionNutation = undefined;
        c.eraPn06a(
            date.part_a,
            date.part_b,
            &result.dpsi,
            &result.deps,
            &result.epsa,
            &result.rb,
            &result.rp,
            &result.rbp,
            &result.rn,
            &result.rbpn,
        );
        return result;
    }

    /// The combined bias-precession-nutation matrix, IAU 2000A model.
    pub fn pnm00a(date: Date2) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraPnm00a(date.part_a, date.part_b, &matrix);
        return matrix;
    }

    /// The combined bias-precession-nutation matrix, IAU 2000B model.
    pub fn pnm00b(date: Date2) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraPnm00b(date.part_a, date.part_b, &matrix);
        return matrix;
    }

    /// The combined bias-precession-nutation matrix, IAU 2006 model.
    pub fn pnm06a(date: Date2) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraPnm06a(date.part_a, date.part_b, &matrix);
        return matrix;
    }

    /// The combined precession-nutation matrix, IAU 1980 model.
    pub fn pnm80(date: Date2) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraPnm80(date.part_a, date.part_b, &matrix);
        return matrix;
    }

    /// The frame-bias-precession matrix, IAU 2000 model.
    pub fn pmat00(date: Date2) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraPmat00(date.part_a, date.part_b, &matrix);
        return matrix;
    }

    /// The frame-bias-precession matrix, IAU 2006 model.
    pub fn pmat06(date: Date2) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraPmat06(date.part_a, date.part_b, &matrix);
        return matrix;
    }

    /// The frame-bias-precession matrix, IAU 1976 model.
    pub fn pmat76(date: Date2) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraPmat76(date.part_a, date.part_b, &matrix);
        return matrix;
    }

    /// The polar motion matrix for observed place, from `xp`, `yp` and the
    /// spurious `sp` term.
    pub fn pom00(polar_motion_x: f64, polar_motion_y: f64, spurious: f64) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraPom00(polar_motion_x, polar_motion_y, spurious, &matrix);
        return matrix;
    }

    /// ICRS to ecliptic rotation matrix, Lieske em model, at a Julian epoch.
    ///
    /// `epoch` is an absolute TT Julian epoch: the year plus its fraction, as
    /// `calendar.epj` returns, so J2000.0 is `2000.0` and not zero
    /// (`src/ltecm.c:13`). Upstream subtracts 2000.0 internally
    /// (`src/ltpequ.c:84`), so passing a count of years from J2000.0 computes
    /// the year 0 instead.
    pub fn ltecm(epoch: f64) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraLtecm(epoch, &matrix);
        return matrix;
    }

    /// ICRS equatorial to ecliptic, Lieske model, at a Julian epoch.
    ///
    /// `epoch` is an absolute TT Julian epoch, as for `ltecm`
    /// (`src/lteqec.c:13`).
    pub fn lteqec(epoch: f64, equatorial: EquatorialCoordinates) EclipticCoordinates {
        var dl: f64 = undefined;
        var db: f64 = undefined;
        c.eraLteqec(epoch, equatorial.right_ascension, equatorial.declination, &dl, &db);
        return .{ .longitude = dl, .latitude = db };
    }

    /// Ecliptic to ICRS equatorial, Lieske model, at a Julian epoch.
    ///
    /// `epoch` is an absolute TT Julian epoch, as for `ltecm`
    /// (`src/lteceq.c:13`).
    pub fn lteceq(epoch: f64, position: EclipticCoordinates) EquatorialCoordinates {
        var dr: f64 = undefined;
        var dd: f64 = undefined;
        c.eraLteceq(epoch, position.longitude, position.latitude, &dr, &dd);
        return .{ .right_ascension = dr, .declination = dd };
    }

    /// Precession matrix, J2000.0 to the epoch, Lieske model.
    ///
    /// `epoch` is an absolute TT Julian epoch, as for `ltecm` (`src/ltp.c:12`).
    pub fn ltp(epoch: f64) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraLtp(epoch, &matrix);
        return matrix;
    }

    /// Precession-bias matrix, J2000.0 to the epoch, Lieske model.
    ///
    /// `epoch` is an absolute TT Julian epoch, as for `ltecm`
    /// (`src/ltpb.c:13`).
    pub fn ltpb(epoch: f64) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraLtpb(epoch, &matrix);
        return matrix;
    }

    /// Ecliptic pole unit vector with respect to the J2000.0 mean equator and
    /// equinox, at a Julian epoch, Lieske model.
    ///
    /// `epoch` is an absolute TT Julian epoch, as for `ltecm`
    /// (`src/ltpecl.c:13`). Upstream declares this `double vec[3]` and
    /// overwrites all three components, so the array is an output only and
    /// this wrapper takes no vector and returns the whole one.
    pub fn ltpecl(epoch: f64) Vec3 {
        var vector: Vec3 = undefined;
        c.eraLtpecl(epoch, &vector);
        return vector;
    }

    /// Equator pole unit vector at a Julian epoch, Lieske model.
    ///
    /// `epoch` is an absolute TT Julian epoch, as for `ltecm`
    /// (`src/ltpequ.c:13`). As for `ltpecl`, the array is an output only:
    /// `src/ltpequ.c` overwrites all three components.
    pub fn ltpequ(epoch: f64) Vec3 {
        var vector: Vec3 = undefined;
        c.eraLtpequ(epoch, &vector);
        return vector;
    }
};

/// The analytical ephemerides: Earth position and velocity from the JPL
/// development ephemeris, the planets from the Bretagnon tables, and the Moon
/// from the lunar theory.
///
/// None of these is IAU-endorsed and none has canonical status; upstream says
/// so in each of their own notes, and this module repeats it rather than
/// letting a caller assume otherwise.
pub const ephemeris = struct {
    /// Earth position and velocity, heliocentric and barycentric, with respect
    /// to the Barycentric Celestial Reference System.
    ///
    /// `date` is a TDB two-part Julian Date; TT may be substituted in most
    /// applications (`src/epv00.c` note 1). Both outputs are in au and au/day
    /// and are always written: the status is `+1` for a date outside
    /// 1900-2100 and never negative, and a warning does not stop the
    /// computation (`src/epv00.c:36-40`).
    pub fn epv00(date: Date2) Epv00Result {
        var heliocentric: Pv = undefined;
        var barycentric: Pv = undefined;
        const status: Status = .{ .value = c.eraEpv00(
            date.part_a,
            date.part_b,
            pvPointer(&heliocentric),
            pvPointer(&barycentric),
        ) };
        return .{ .status = status, .heliocentric = heliocentric, .barycentric = barycentric };
    }

    /// Heliocentric position and velocity of a planet, J2000.0, au and
    /// au/day.
    ///
    /// `planet` is 1 Mercury, 2 Venus, 3 Earth-Moon barycentre, 4 Mars,
    /// 5 Jupiter, 6 Saturn, 7 Uranus, 8 Neptune. A number outside 1-8 gives
    /// `-1` and a zeroed vector (`src/plan94.c`); a year outside 1000-3000
    /// gives the warning `+1`, and a Kepler-solver failure to converge gives
    /// `+2`. Both warnings still produce a vector.
    pub fn plan94(date: Date2, planet: i32) Plan94Result {
        var pv: Pv = undefined;
        const status: Status = .{ .value = c.eraPlan94(
            date.part_a,
            date.part_b,
            planet,
            pvPointer(&pv),
        ) };
        return .{ .status = status, .pv = pv };
    }

    /// Geocentric position and velocity of the Moon, au and au/day.
    ///
    /// Upstream returns no status for this one (`src/moon98.c:3`), so neither
    /// does this wrapper, and there is no warning to lose.
    pub fn moon98(date: Date2) Pv {
        var pv: Pv = undefined;
        c.eraMoon98(date.part_a, date.part_b, pvPointer(&pv));
        return pv;
    }
};

/// The plain vector helpers the transformations are built from.
pub const vectors = struct {
    /// Split a p-vector into its modulus and its unit direction.
    ///
    /// The zero vector has no direction, and upstream returns a zero unit
    /// vector rather than failing (`src/pn.c`); `modulus` is therefore 0 and
    /// `unit` is all zeros in that case, and no status is invented for it.
    pub fn pn(p: *const Vec3) PnResult {
        var modulus: f64 = undefined;
        var unit: Vec3 = undefined;
        c.eraPn(@constCast(p), &modulus, &unit);
        return .{ .modulus = modulus, .unit = unit };
    }

    /// The magnitude of a p-vector.
    pub fn pm(p: *const Vec3) f64 {
        return c.eraPm(@constCast(p));
    }

    /// Apply light deflection by a solar-system body.
    ///
    /// `body_mass` is the body's mass in solar masses. `observer_distance` is
    /// the distance from the body to the observer **in au**, not a companion
    /// mass: upstream divides the deflection by it (`src/ld.c:14-20`, `:88-89`).
    /// `p` is the direction from observer to source, `q` from body to source
    /// and `e` from body to observer, all unit vectors. `deflection_limiter` is
    /// `phi^2/2`, where `phi` in radians is the source-to-body separation at
    /// which limiting starts (`src/ld.c:39-43`). All three vectors are only
    /// read; the deflected direction is returned by value, and upstream notes
    /// that it is not normalised (`src/ld.c:45-46`).
    pub fn ld(
        body_mass: f64,
        p: *const Vec3,
        q: *const Vec3,
        e: *const Vec3,
        observer_distance: f64,
        deflection_limiter: f64,
    ) Vec3 {
        var deflected: Vec3 = undefined;
        c.eraLd(
            body_mass,
            @constCast(p),
            @constCast(q),
            @constCast(e),
            observer_distance,
            deflection_limiter,
            &deflected,
        );
        return deflected;
    }

    /// The scalar product of two p-vectors.
    pub fn pdp(a: *const Vec3, b: *const Vec3) f64 {
        return c.eraPdp(@constCast(a), @constCast(b));
    }

    /// `a - b`, componentwise.
    pub fn pmp(a: *const Vec3, b: *const Vec3) Vec3 {
        var difference: Vec3 = undefined;
        c.eraPmp(@constCast(a), @constCast(b), &difference);
        return difference;
    }

    /// `a + b`, componentwise.
    pub fn ppp(a: *const Vec3, b: *const Vec3) Vec3 {
        var sum: Vec3 = undefined;
        c.eraPpp(@constCast(a), @constCast(b), &sum);
        return sum;
    }

    /// `s * a + b`: a scaled vector plus a second one.
    pub fn ppsp(a: *const Vec3, s: f64, b: *const Vec3) Vec3 {
        var result: Vec3 = undefined;
        c.eraPpsp(@constCast(a), s, @constCast(b), &result);
        return result;
    }

    /// The cross product `a x b`.
    pub fn pxp(a: *const Vec3, b: *const Vec3) Vec3 {
        var product: Vec3 = undefined;
        c.eraPxp(@constCast(a), @constCast(b), &product);
        return product;
    }

    /// `s * p`.
    pub fn sxp(s: f64, p: *const Vec3) Vec3 {
        var result: Vec3 = undefined;
        c.eraSxp(s, @constCast(p), &result);
        return result;
    }

    /// `s * pv`, applied to both members.
    pub fn sxpv(s: f64, pv: Pv) Pv {
        var result: Pv = undefined;
        c.eraSxpv(s, pvPointer(&pv), pvPointer(&result));
        return result;
    }

    /// `p` scaled by `s1` and `v` scaled by `s2`, as a pv-vector.
    ///
    /// The two members are scaled separately and both come back: upstream is
    /// two `eraSxp` calls (`src/s2xpv.c:31-32`) and declares the output as
    /// `double spv[2][3]` (`src/erfa.h:517`). It is not the vector sum
    /// `s1 * p + s2 * v`, which is three numbers and not what the header says
    /// this computes.
    pub fn s2xpv(s1: f64, s2: f64, pv: Pv) Pv {
        var result: Pv = undefined;
        c.eraS2xpv(s1, s2, pvPointer(&pv), pvPointer(&result));
        return result;
    }

    /// The modulus of the position and the speed, from a position and a
    /// velocity together.
    ///
    /// Upstream returns no status here (`src/pvm.c`), so neither does this. The
    /// two numbers are independent: `radius` is `pm(position)` and `speed` is
    /// `pm(velocity)`, and nothing here compares the speed with the speed of
    /// light, which is the check that exists in SOFA's own history and not in
    /// this source.
    pub fn pvm(pv: Pv) PvModulus {
        var radius: f64 = undefined;
        var speed: f64 = undefined;
        c.eraPvm(pvPointer(&pv), &radius, &speed);
        return .{ .radius = radius, .speed = speed };
    }

    /// The position after `dt` days, by `dt * v`.
    pub fn pvu(dt: f64, pv: Pv) Pv {
        var result: Pv = undefined;
        c.eraPvu(dt, pvPointer(&pv), pvPointer(&result));
        return result;
    }

    /// The position after `dt` days, as a p-vector rather than a pv.
    ///
    /// Upstream computes the whole `dt * pv` and returns only its first three
    /// components (`src/pvup.c`).
    pub fn pvup(dt: f64, pv: Pv) Vec3 {
        var position: Vec3 = undefined;
        c.eraPvup(dt, pvPointer(&pv), &position);
        return position;
    }

    /// The scalar product of the positions and of position with velocity:
    /// `a_p . b_p` and `a_p . b_v`.
    pub fn pvdpv(a: Pv, b: Pv) PvDotProduct {
        var products: [2]f64 = undefined;
        c.eraPvdpv(pvPointer(&a), pvPointer(&b), &products);
        return .{ .position_position = products[0], .position_velocity = products[1] };
    }

    /// `a - b` for a position and a velocity together.
    pub fn pvmpv(a: Pv, b: Pv) Pv {
        var result: Pv = undefined;
        c.eraPvmpv(pvPointer(&a), pvPointer(&b), pvPointer(&result));
        return result;
    }

    /// `a + b` for a position and a velocity together.
    pub fn pvppv(a: Pv, b: Pv) Pv {
        var result: Pv = undefined;
        c.eraPvppv(pvPointer(&a), pvPointer(&b), pvPointer(&result));
        return result;
    }

    /// The cross product of two position/velocity pairs, computed for both
    /// members as upstream does (`src/pvxpv.c`).
    pub fn pvxpv(a: Pv, b: Pv) Pv {
        var result: Pv = undefined;
        c.eraPvxpv(pvPointer(&a), pvPointer(&b), pvPointer(&result));
        return result;
    }

    /// Position angle of b with respect to a, in `[-pi, pi]` radians.
    /// North is zero and east is positive. Returns zero for coincident
    /// directions or a zero-length operand (`src/pap.c`).
    pub fn pap(a: *const Vec3, b: *const Vec3) f64 {
        return c.eraPap(@constCast(a), @constCast(b));
    }

    /// The angular separation of two p-vectors, in radians in `[0, pi]`.
    ///
    /// Returns zero if either operand has zero length (`src/sepp.c`).
    pub fn sepp(a: *const Vec3, b: *const Vec3) f64 {
        return c.eraSepp(@constCast(a), @constCast(b));
    }

    /// Position angle of b with respect to a, given longitude and latitude.
    pub fn pas(alpha_l: f64, alpha_p: f64, beta_l: f64, beta_p: f64) f64 {
        return c.eraPas(alpha_l, alpha_p, beta_l, beta_p);
    }

    /// Angular separation given longitude and latitude, in `[0, pi]` radians.
    pub fn seps(alpha_l: f64, alpha_p: f64, beta_l: f64, beta_p: f64) f64 {
        return c.eraSeps(alpha_l, alpha_p, beta_l, beta_p);
    }

    /// The combined gravitational deflection by several solar-system bodies,
    /// `eraLdn`.
    ///
    /// The declaration is
    /// `eraLdn(int n, eraLDBODY b[], double ob[3], double sc[3], double sn[3])`
    /// (`erfa.h:156-157`) and the body at this pin does not do what that name
    /// suggests, so the wrapper models what it does rather than what it is
    /// called. `src/ldn.c:96` copies the caller's `sc` into `sn` and then the
    /// loop only ever writes `sn` (`src/ldn.c:99-120`): `sc` comes back exactly
    /// as it went in, and the accumulated deflection lands in `sn`. That is
    /// why `direction` is an argument here and why `in_place` is returned
    /// unchanged rather than as a computed component.
    ///
    /// `observer` is the observer's offset from the solar-system barycentre in
    /// au; `bodies[i].pv[0]` and `pv[1]` are the body's barycentric position
    /// and velocity in au and au/day; `direction` is the line of sight the
    /// bodies bend. Upstream returns no status, and an empty body list is not
    /// an error: the copy at `src/ldn.c:96` still happens, so the deflected
    /// vector comes back equal to `direction`.
    pub fn ldn(
        bodies: []const LightDeflectingBody,
        observer: *const Vec3,
        direction: *const Vec3,
    ) LightDeflection {
        var in_place = direction.*;
        var deflected: Vec3 = undefined;
        c.eraLdn(@intCast(bodies.len), @constCast(bodies.ptr), @constCast(observer), &in_place, &deflected);
        return .{ .in_place = in_place, .deflected = deflected };
    }

    /// The deflection by the Sun alone, `eraLdsun`.
    ///
    /// `p` is the unit vector from observer to source, `e` the unit vector from
    /// Sun to observer and `observer_distance` the Sun-observer distance in au,
    /// all three read only. The returned direction is not normalised, which
    /// `ld`'s documentation already says about the single-body form.
    pub fn ldsun(
        p: *const Vec3,
        e: *const Vec3,
        observer_distance: f64,
    ) Vec3 {
        var deflected: Vec3 = undefined;
        c.eraLdsun(@constCast(p), @constCast(e), observer_distance, &deflected);
        return deflected;
    }

    /// The relativistic aberration of a direction.
    ///
    /// `natural_direction` and `velocity` are unit vectors,
    /// `observer_distance` is the distance between the Sun and the observer
    /// in au (`src/ab.c:17`, consumed as `w2 = ERFA_SRS/s` at `:64`), and
    /// `lorenz_reciprocal` is `sqrt(1 - |v|^2)`. All three vectors are read
    /// only and the result is a unit vector.
    pub fn ab(
        natural_direction: *const Vec3,
        velocity: *const Vec3,
        observer_distance: f64,
        lorenz_reciprocal: f64,
    ) Vec3 {
        var aberrated: Vec3 = undefined;
        c.eraAb(
            @constCast(natural_direction),
            @constCast(velocity),
            observer_distance,
            lorenz_reciprocal,
            &aberrated,
        );
        return aberrated;
    }

    /// The observer's position and velocity in the BCRS from the observer's
    /// known quantities, `eraPvtob`.
    ///
    /// Every argument is a quantity the observer supplies: longitude and
    /// latitude and height in metres, the polar motion coordinates, the
    /// spurious `sp` term, and the Earth rotation angle in radians. The
    /// result is au and au/day.
    pub fn pvtob(longitude: f64, latitude: f64, height: f64, xp: f64, yp: f64, sp: f64, era: f64) Pv {
        var result: Pv = undefined;
        c.eraPvtob(longitude, latitude, height, xp, yp, sp, era, pvPointer(&result));
        return result;
    }

    /// The space motion of a star from its position and velocity, `eraPvstar`.
    ///
    /// The status ladder is upstream's: `-1` is the pathological case where
    /// `1 + beta_r` is zero or `w > 1`, and `-2` is a zero position vector.
    /// Both return before writing any output scalar (`src/pvstar.c:29-36`), so
    /// `star` is `null` for them.
    ///
    /// This is also the one wrapper in the module whose native routine writes
    /// its own pv argument: `eraPvstar` replaces `pv[1]` with the
    /// space-travelled velocity before it converts (`src/pvstar.c:133`). It
    /// takes the argument as a copy for that reason and not for tidiness. A
    /// by-value parameter is not guaranteed to be a private object - an
    /// aggregate may be passed by reference and mutated through the callee's
    /// pointer - so a caller that kept `var pv` would otherwise watch its own
    /// velocity change under a call documented as a query. The discarded copy
    /// is the ownership contract; every other pv argument in this module is
    /// read-only in upstream and is passed straight through.
    pub fn pvstar(pv: Pv) StarMotionResult {
        var travel = pv;
        var ra: f64 = undefined;
        var dec: f64 = undefined;
        var pm_ra: f64 = undefined;
        var pm_dec: f64 = undefined;
        var parallax: f64 = undefined;
        var radial_velocity: f64 = undefined;
        const status: Status = .{ .value = c.eraPvstar(
            pvPointer(&travel),
            &ra,
            &dec,
            &pm_ra,
            &pm_dec,
            &parallax,
            &radial_velocity,
        ) };
        if (status.isError()) return .{ .status = status, .star = null };
        return .{ .status = status, .star = .{
            .right_ascension = ra,
            .declination = dec,
            .pm_ra = pm_ra,
            .pm_dec = pm_dec,
            .parallax = parallax,
            .radial_velocity = radial_velocity,
        } };
    }

    /// The position and velocity of a star from its catalogue quantities,
    /// `eraStarpv`.
    ///
    /// Upstream returns no status and no error: the status it returns is a
    /// warning ladder with `+1` for a parallax below its internal floor of
    /// `1e-7` arcsec, `+2` for a velocity above half the speed of light - in
    /// which case the velocity is zeroed by `eraZp` and the answer is *not*
    /// the input - and `+4` for a solver that did not converge
    /// (`src/starpv.c:16-18`, `:64`). There is no negative case. `pv` is
    /// therefore present for every status, and `status.isWarning()` is what
    /// says whether it may be used as given.
    pub fn starpv(star: StarMotion) PvResult {
        var pv: Pv = undefined;
        const status: Status = .{ .value = c.eraStarpv(
            star.right_ascension,
            star.declination,
            star.pm_ra,
            star.pm_dec,
            star.parallax,
            star.radial_velocity,
            pvPointer(&pv),
        ) };
        return .{ .status = status, .pv = pv };
    }

    /// The space motion of a star at a second epoch, `eraStarpm`.
    ///
    /// Each epoch is a two-part Julian Date in the same BCRS convention
    /// `starpv` uses. The status is upstream's, and its rule is
    /// `j = (j2 == 0) ? j1 : -1`, with `j1` from `starpv` and `j2` from
    /// `pvstar` (`src/starpm.c:122,148,151`). A warning from `starpv` is
    /// carried out unchanged; every failure of `pvstar` collapses to `-1`,
    /// so `pvstar`'s own `-2` for a null position vector
    /// (`src/pvstar.c:137`) cannot escape this call. `-1` is reached either
    /// that way or through upstream's own `c^2 - v^2 <= 0` test
    /// (`src/starpm.c:139-140`). `starpv` has no negative status of its own
    /// (its ladder is `0`, `+1`, `+2`, `+4`, `src/starpv.c:25-31`), so the
    /// collapse discards no warning. `star` is `null` for every negative
    /// status.
    pub fn starpm(star: StarMotion, from: Date2, to: Date2) StarMotionResult {
        var ra2: f64 = undefined;
        var dec2: f64 = undefined;
        var pm_ra2: f64 = undefined;
        var pm_dec2: f64 = undefined;
        var px2: f64 = undefined;
        var rv2: f64 = undefined;
        const status: Status = .{ .value = c.eraStarpm(
            star.right_ascension,
            star.declination,
            star.pm_ra,
            star.pm_dec,
            star.parallax,
            star.radial_velocity,
            from.part_a,
            from.part_b,
            to.part_a,
            to.part_b,
            &ra2,
            &dec2,
            &pm_ra2,
            &pm_dec2,
            &px2,
            &rv2,
        ) };
        if (status.isError()) return .{ .status = status, .star = null };
        return .{ .status = status, .star = .{
            .right_ascension = ra2,
            .declination = dec2,
            .pm_ra = pm_ra2,
            .pm_dec = pm_dec2,
            .parallax = px2,
            .radial_velocity = rv2,
        } };
    }

    /// The space motion of a star at a second epoch, with the parallax
    /// defended against a proper motion that would make it meaningless,
    /// `eraPmsafe`.
    ///
    /// Upstream raises the caller's parallax to `326 * sep` in radians, and to
    /// a floor of `5e-7` arcsec, before calling `starpm`
    /// (`src/pmsafe.c:116,119,126-138`), and adds a `+1` warning when it had
    /// to. The returned parallax is therefore **not** the input parallax; that
    /// is the point of the routine and it is stated here because a caller that
    /// treats this as `starpm` will be wrong for a nearby star.
    pub fn pmsafe(star: StarMotion, from: Date2, to: Date2) StarMotionResult {
        var ra2: f64 = undefined;
        var dec2: f64 = undefined;
        var pm_ra2: f64 = undefined;
        var pm_dec2: f64 = undefined;
        var px2: f64 = undefined;
        var rv2: f64 = undefined;
        const status: Status = .{ .value = c.eraPmsafe(
            star.right_ascension,
            star.declination,
            star.pm_ra,
            star.pm_dec,
            star.parallax,
            star.radial_velocity,
            from.part_a,
            from.part_b,
            to.part_a,
            to.part_b,
            &ra2,
            &dec2,
            &pm_ra2,
            &pm_dec2,
            &px2,
            &rv2,
        ) };
        if (status.isError()) return .{ .status = status, .star = null };
        return .{ .status = status, .star = .{
            .right_ascension = ra2,
            .declination = dec2,
            .pm_ra = pm_ra2,
            .pm_dec = pm_dec2,
            .parallax = px2,
            .radial_velocity = rv2,
        } };
    }

    /// Where a star's space motion takes it, `eraPmpx`.
    ///
    /// `catalogue_position` is the position at the catalogue epoch and
    /// `pm_years` the interval from that epoch to the observation, in Julian
    /// years. `observer_offset` is the solar-system barycenter to observer
    /// vector in au. Upstream reads it and returns one BCRS unit direction
    /// (`src/pmpx.c:14-24`).
    pub fn pmpx(
        catalogue_position: ObservedSpherical,
        proper_motion: ObservedSpherical,
        parallax: f64,
        radial_velocity: f64,
        pm_years: f64,
        observer_offset: *const Vec3,
    ) Vec3 {
        var direction: Vec3 = undefined;
        c.eraPmpx(
            catalogue_position.first,
            catalogue_position.second,
            proper_motion.first,
            proper_motion.second,
            parallax,
            radial_velocity,
            pm_years,
            @constCast(observer_offset),
            &direction,
        );
        return direction;
    }
};

// ---------------------------------------------------------------------------
// Record types for the rest of the translated surface
//
// Every one of them is a shape this module chose for a group of outputs
// upstream declares as loose out-parameters. Nothing is allocated, and no
// value is derived here: a number in one of these came out of a C routine.
// ---------------------------------------------------------------------------

/// One solar-system body that light is deflected by, upstream's `eraLDBODY`
/// unchanged (`erfa.h:44-48`).
///
/// The raw route publishes the record itself; this alias gives the array form
/// `ldn` takes a name without restating the layout.
pub const LightDeflectingBody = c.eraLDBODY;

/// The two vectors `vectors.ldn` hands back, named for what upstream's own
/// arguments do rather than for what the names `sc` and `sn` suggest.
///
/// Upstream copies the caller's `sc` into `sn` and never writes `sc` again
/// (`src/ldn.c:96`), so `in_place` is the caller's own vector, returned with
/// whatever magnitude the caller gave it. `deflected` is `sn`: the direction
/// the bodies bent it into, and it is **not** renormalised. `eraLd` states
/// that its result "is not normalized" (`src/ld.c:45-46`) and `eraLdn` says
/// the same of `sn` (`src/ldn.c:59-60`), so `deflected` is a direction, not a
/// unit vector; renormalise it before using it as one. The departure from
/// unit magnitude is negligible only because the three input directions are
/// documented as unit vectors, and upstream deliberately omits the validation
/// that would enforce it (`src/ld.c:55-57`, `src/ldn.c:64-66`). Within one
/// call `sn` is `eraLd`'s input and its output for every body in turn
/// (`src/ldn.c:117`) and is what the light-time term reads (`:105`), so the
/// departure is carried through the loop rather than reset per body.
pub const LightDeflection = struct {
    /// Upstream's `sc`: exactly the `direction` that was passed in.
    in_place: Vec3,
    /// Upstream's `sn`: the deflected direction.
    deflected: Vec3,
};

/// A position's modulus and a velocity's modulus, from `vectors.pvm`.
pub const PvModulus = struct {
    /// `pm(position)`.
    radius: f64,
    /// `pm(velocity)`.
    speed: f64,
};

/// The two scalar products `vectors.pvdpv` computes.
pub const PvDotProduct = struct {
    /// `a_p . b_p`.
    position_position: f64,
    /// `a_p . b_v`.
    position_velocity: f64,
};

/// The six numbers a star carries: two angles, two proper motions, a parallax
/// and a radial velocity.
///
/// The same six quantities are what `starpv` and `pvstar` exchange and what
/// every star-catalogue transformation moves between frames, so one record
/// covers both. Units are upstream's and differ per member: the angles are
/// radians, the proper motions are radians per Julian year, the parallax is
/// arcseconds and the radial velocity is km/s.
pub const StarMotion = struct {
    /// Right ascension, radians.
    right_ascension: f64,
    /// Declination, radians.
    declination: f64,
    /// Proper motion in right ascension, radians per Julian year.
    pm_ra: f64,
    /// Proper motion in declination, radians per Julian year.
    pm_dec: f64,
    /// Parallax, arcseconds.
    parallax: f64,
    /// Radial velocity, km/s.
    radial_velocity: f64,
};

/// The result of a routine that converts a star to or from space motion.
///
/// `star` is `null` exactly when the status is negative, which is the set of
/// statuses upstream returns before writing any output.
pub const StarMotionResult = struct {
    /// See the function's documentation for the ladder.
    status: Status,
    /// The star's six quantities, or `null` when upstream wrote nothing.
    star: ?StarMotion,
};

/// The result of `vectors.starpv`, which always computes and can only warn.
pub const PvResult = struct {
    /// `0` OK; `+1` parallax below the internal floor; `+2` velocity above
    /// half the speed of light; `+3` both; `+4` the solver did not converge.
    status: Status,
    /// Position and velocity. Always present, because upstream has no negative
    /// status here.
    pv: Pv,
};


/// The sign and four fields `angles.a2af` writes: degrees, arcminutes,
/// arcseconds and a fraction.
///
/// The field ranges come from `eraD2tf`, which `eraA2af` calls
/// (`src/a2af.c:5`): degrees run 0 to 23 rather than 0 to 359, arcminutes 0 to
/// 59 and arcseconds 0 to 60, where 60 is upstream's rounding and is not
/// carried into the next field. The fraction is in units of `10^-ndp` and is
/// not normalised. Upstream returns no status (`src/a2af.c:3`).
pub const A2afResult = struct {
    /// `'+'` or `'-'`, from upstream.
    sign: u8,
    /// Degrees, 0 to 23.
    degrees: i32,
    /// Arcminutes, 0 to 59.
    arcminutes: i32,
    /// Arcseconds, 0 to 60.
    arcseconds: i32,
    /// Fraction of an arcsecond in units of `10^-ndp`.
    fraction: i32,
};

/// The sign and four fields `angles.a2tf` writes: hours, minutes, seconds and
/// a fraction, with the same ranges and the same unrounded fraction as
/// `calendar.d2tf`, because `eraA2tf` calls it (`src/a2tf.c:5`).
pub const A2tfResult = struct {
    /// `'+'` or `'-'`, from upstream.
    sign: u8,
    /// Hours, 0 to 23.
    hours: i32,
    /// Minutes, 0 to 59.
    minutes: i32,
    /// Seconds, 0 to 60.
    seconds: i32,
    /// Fraction of a second in units of `10^-ndp`.
    fraction: i32,
};

/// The `a`/`b` pair a gnomonic projection uses.
///
/// Upstream names the two angles `a` and `b` and says which frame they are in
/// only in the caller's terms, so neither is renamed here: a caller who has a
/// frame in mind supplies it, and this record does not imply one.
pub const StandardCoordinates = struct {
    /// The `a` angle, radians.
    a: f64,
    /// The `b` angle, radians.
    b: f64,
};

/// The result of `gnomonic.tpors`, the standard-coordinate form of the tangent
/// plane projection.
///
/// Upstream's integer is a **count of useful solutions**, not the usual ERFA
/// status (`src/tpors.c:22-26`), and the difference is visible here: `0` is the
/// case where **nothing** was written (`src/tpors.c:115-117`), so `isOk()` is
/// true and both members are `null`. A caller must read `first` rather than the
/// status to know whether there is an answer, and must not read `isWarning()`
/// as one either: every non-zero count is positive, so both `1` and `2` answer
/// it and neither is a warning.
pub const TporsResult = struct {
    /// How many solutions upstream found useful: `0` none were returned, `1`
    /// only `Soln. 1` is useful - the usual case - and `2` both are, which
    /// arises near the poles (`src/tpors.c:23-26,47-56`; the choice between
    /// `1` and `2` is `(fabs(rsb) < 1.0) ? 1 : 2` at `src/tpors.c:114`).
    status: Status,
    /// Upstream's `Soln. 1` (`src/tpors.c:19-20`), or `null` when the count is
    /// `0`. It is written whenever upstream writes anything at all
    /// (`src/tpors.c:107-108`).
    first: ?StandardCoordinates,
    /// Upstream's `Soln. 2`, or `null` when the count is `0`
    /// (`src/tpors.c:112-113`). A count of `1` says this one is *not useful*,
    /// not that upstream left it absent: both are written on the same path.
    second: ?StandardCoordinates,
};

/// The result of `gnomonic.tporv`, the Cartesian form of the same projection.
pub const TporvResult = struct {
    /// As `TporsResult.status`: the count of useful solutions, `0`, `1` or `2`
    /// (`src/tporv.c:22-26`; decided by the same `(fabs(rsb) < 1.0) ? 1 : 2` at
    /// `src/tporv.c:111`).
    status: Status,
    /// Upstream's `Solution 1`, or `null` when the count is `0`
    /// (`src/tporv.c:19-20,103-105`).
    first: ?Vec3,
    /// Upstream's `Solution 2`, or `null` when the count is `0`
    /// (`src/tporv.c:108-110`). A count of `1` says this one is not useful, not
    /// that upstream left it absent.
    second: ?Vec3,
};

/// The result of `gnomonic.tpxes` and `gnomonic.tpxev`, the inverse
/// projections.
///
/// Both always write both fields: upstream clamps the divisor to `+-1e-6`
/// rather than dividing by zero (`src/tpxes.c:19-27`, `src/tpxev.c:24-32`),
/// so the status is the report of a near-singular input and not of a missing
/// answer.
pub const TpxeResult = struct {
    /// `0` the point is well inside the tangent plane; `+1` it is within
    /// `1e-6` of the great circle and the divisor was clamped to `+1e-6`;
    /// `+2` it is within `1e-6` *behind* the great circle and the divisor was
    /// clamped to `-1e-6`; `+3` it is behind the great circle.
    status: Status,
    /// The standard coordinates `xi` and `eta`, always present.
    coordinates: StandardCoordinates,
};

/// The rotation and the vector `eraFk5hip` defines for the Hipparcos-to-FK5
/// transformation.
pub const Fk5HipResult = struct {
    /// The B5-to-FK5-Hipparcos rotation matrix.
    rotation: Mat3,
    /// The FK5 spin rotation vector with respect to Hipparcos, in radians per
    /// Julian year (TDB, `src/fk5hip.c:14-19`). It is a rate, not an E-terms
    /// offset: `eraFk52h` divides it by `365.25` to get a per-day rate
    /// (`src/fk52h.c:73-80`) and `eraHfk5z` turns it with `eraRv2m`
    /// (`src/hfk5z.c:100-104`).
    spin: Vec3,
};

/// The two refraction constants `atmosphere.refco` computes.
pub const RefractionConstants = struct {
    /// Refraction constant A, radians.
    a: f64,
    /// Refraction constant B, radians.
    b: f64,
};

/// The two angles a Cartesian direction is decomposed into.
///
/// `eraC2s` does **not** normalise them (`src/c2s.c:8-9`): `theta` is whatever
/// `atan2` returns, so it is negative for a direction in the fourth quadrant,
/// and both are `0.0` for a zero vector. A caller that wants the angles in a
/// fixed range applies `angles.anp` and `angles.anpm`, which is what upstream's
/// own `eraG2icrs` does after calling it (`src/g2icrs.c:20-21`).
pub const SphericalAngles = struct {
    /// The longitude-like angle, radians, as `atan2` returned it.
    theta: f64,
    /// The latitude-like angle, radians, in `[-pi/2, pi/2]`.
    phi: f64,
};

/// A Cartesian point as two angles and a distance, from `spherical.p2s`.
pub const CartesianSpherical = struct {
    /// See `SphericalAngles.theta`.
    theta: f64,
    /// See `SphericalAngles.phi`.
    phi: f64,
    /// The modulus of the point, in the caller's units.
    radius: f64,
};

/// A position and a velocity as two angles, a distance and three rates, from
/// `spherical.pv2s`.
///
/// The rates are the spherical components of the velocity with the same scale
/// on all three: `radius_rate` is d(radius)/dt, and the two angle rates are the
/// derivatives of the two angles themselves, not the `d/dtheta`-weighted
/// components SOFA also defines.
pub const PvSpherical = struct {
    /// See `SphericalAngles.theta`.
    theta: f64,
    /// See `SphericalAngles.phi`.
    phi: f64,
    /// The modulus of the position, in the caller's units.
    radius: f64,
    /// The rate of change of `theta`, radians per unit time.
    theta_rate: f64,
    /// The rate of change of `phi`, radians per unit time.
    phi_rate: f64,
    /// The rate of change of `radius`, units per unit time.
    radius_rate: f64,
};

/// Rotation matrices, and the operations on them and on the vectors they act
/// on.
///
/// Axis rotation constructors initialize the identity before upstream's
/// in-place rotation. Other outputs are written in full and returned by value.
/// None of these functions returns a status. Both arguments of a two-matrix or matrix-and-vector
/// call are read only, and upstream declares them without `const`; the
/// `@constCast` calls below are the places this module deliberately gives that
/// back, and each names a file in which the argument is only read.
pub const matrices = struct {
    /// The matrix that rotates about the first axis by `phi`, radians.
    pub fn rotateX(phi: f64) Mat3 {
        var matrix = identity();
        c.eraRx(phi, &matrix);
        return matrix;
    }

    /// The matrix that rotates about the second axis by `theta`, radians.
    pub fn rotateY(theta: f64) Mat3 {
        var matrix = identity();
        c.eraRy(theta, &matrix);
        return matrix;
    }

    /// The matrix that rotates about the third axis by `psi`, radians.
    pub fn rotateZ(psi: f64) Mat3 {
        var matrix = identity();
        c.eraRz(psi, &matrix);
        return matrix;
    }

    /// The identity matrix.
    ///
    /// Upstream writes all nine entries rather than only the diagonal
    /// (`src/ir.c:5-13`), so this is the whole matrix and not a diagonal with
    /// whatever the caller happened to have left in the other six.
    pub fn identity() Mat3 {
        var matrix: Mat3 = undefined;
        c.eraIr(&matrix);
        return matrix;
    }

    /// The zero matrix.
    pub fn zero() Mat3 {
        var matrix: Mat3 = undefined;
        c.eraZr(&matrix);
        return matrix;
    }

    /// The zero vector.
    pub fn zeroVector() Vec3 {
        var vector: Vec3 = undefined;
        c.eraZp(&vector);
        return vector;
    }

    /// The zero position/velocity pair.
    pub fn zeroPv() Pv {
        var pv: Pv = undefined;
        c.eraZpv(pvPointer(&pv));
        return pv;
    }

    /// The matrix product `a * b`.
    ///
    /// Upstream's parameter is named `atb` and computes exactly `a` times `b`,
    /// the conventional reading of a row-major matrix product
    /// (`src/rxr.c:11-15`).
    pub fn multiply(a: *const Mat3, b: *const Mat3) Mat3 {
        var product: Mat3 = undefined;
        c.eraRxr(@constCast(a), @constCast(b), &product);
        return product;
    }

    /// The transpose of a matrix.
    pub fn transpose(matrix: *const Mat3) Mat3 {
        var transposed: Mat3 = undefined;
        c.eraTr(@constCast(matrix), &transposed);
        return transposed;
    }

    /// `matrix * p`.
    pub fn apply(matrix: *const Mat3, p: *const Vec3) Vec3 {
        var product: Vec3 = undefined;
        c.eraRxp(@constCast(matrix), @constCast(p), &product);
        return product;
    }

    /// `matrix * pv`, applied to both members.
    pub fn applyPv(matrix: *const Mat3, pv: Pv) Pv {
        var result: Pv = undefined;
        c.eraRxpv(@constCast(matrix), pvPointer(&pv), pvPointer(&result));
        return result;
    }

    /// `transpose(matrix) * p`, which is what upstream computes by
    /// transposing first and then multiplying (`src/trxp.c:6-7`).
    pub fn applyTransposed(matrix: *const Mat3, p: *const Vec3) Vec3 {
        var product: Vec3 = undefined;
        c.eraTrxp(@constCast(matrix), @constCast(p), &product);
        return product;
    }

    /// `transpose(matrix) * pv`, applied to both members.
    pub fn applyTransposedPv(matrix: *const Mat3, pv: Pv) Pv {
        var result: Pv = undefined;
        c.eraTrxpv(@constCast(matrix), pvPointer(&pv), pvPointer(&result));
        return result;
    }

    /// The rotation vector of a matrix: a vector whose direction is the
    /// rotation axis and whose length is the rotation angle.
    ///
    /// The identity and the rotations by zero give the zero vector
    /// (`src/rm2v.c:12-16`), and a rotation by `pi` about an arbitrary axis is
    /// the case where the sign of the vector is chosen by the branch, so
    /// `toRotationVector(fromRotationVector(w))` returns `w` or `-w` for that
    /// one vector.
    pub fn toRotationVector(matrix: *const Mat3) Vec3 {
        var vector: Vec3 = undefined;
        c.eraRm2v(@constCast(matrix), &vector);
        return vector;
    }

    /// The matrix of a rotation vector: the axis is the vector's direction and
    /// the angle is its length.
    ///
    /// Upstream returns the identity for a zero vector (`src/rv2m.c:14-17`).
    pub fn fromRotationVector(vector: *const Vec3) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraRv2m(@constCast(vector), &matrix);
        return matrix;
    }

    /// A copy of a vector.
    ///
    /// This is upstream's own routine rather than a Zig copy, because it is the
    /// routine every other transformation in this library uses and a caller may
    /// want to know that the library agrees with its own copy.
    pub fn copyVector(p: *const Vec3) Vec3 {
        var copy: Vec3 = undefined;
        c.eraCp(@constCast(p), &copy);
        return copy;
    }

    /// A copy of a matrix.
    pub fn copyMatrix(matrix: *const Mat3) Mat3 {
        var copy: Mat3 = undefined;
        c.eraCr(@constCast(matrix), &copy);
        return copy;
    }

    /// A copy of a position and velocity pair.
    pub fn copyPv(pv: Pv) Pv {
        var result: Pv = undefined;
        c.eraCpv(pvPointer(&pv), pvPointer(&result));
        return result;
    }

    /// A position with a zero velocity.
    pub fn positionToPv(p: *const Vec3) Pv {
        var pv: Pv = undefined;
        c.eraP2pv(@constCast(p), pvPointer(&pv));
        return pv;
    }

    /// The position of a position/velocity pair, discarding the velocity.
    pub fn pvToPosition(pv: Pv) Vec3 {
        var position: Vec3 = undefined;
        c.eraPv2p(pvPointer(&pv), &position);
        return position;
    }
};

/// Angle normalisation and the sexagesimal decomposition of an angle.
///
/// `anp` and `anpm` are what the rest of the library uses to bring an angle
/// into a fixed range, and they are exposed here because the difference
/// matters: the same input comes back as two different angles.
pub const angles = struct {
    /// `a` normalised into `[0, 2*pi)`, radians.
    pub fn anp(a: f64) f64 {
        return c.eraAnp(a);
    }

    /// `a` normalised into `[-pi, pi)`, radians.
    pub fn anpm(a: f64) f64 {
        return c.eraAnpm(a);
    }

    /// An angle in radians as degrees, arcminutes, arcseconds and a fraction.
    ///
    /// See `A2afResult` for the field ranges; they come from `eraD2tf`, which
    /// `eraA2af` calls, so a day-of-angle decomposition carries a first field
    /// of 0 to 23 rather than 0 to 359. Upstream returns no status.
    pub fn a2af(ndp: i32, angle: f64) A2afResult {
        var sign: u8 = undefined;
        var idmsf: [4]c_int = undefined;
        c.eraA2af(ndp, angle, &sign, &idmsf);
        return .{
            .sign = sign,
            .degrees = idmsf[0],
            .arcminutes = idmsf[1],
            .arcseconds = idmsf[2],
            .fraction = idmsf[3],
        };
    }

    /// An angle in radians as hours, minutes, seconds and a fraction, i.e. the
    /// angle measured as a time of day.
    ///
    /// See `A2tfResult`. Upstream returns no status.
    pub fn a2tf(ndp: i32, angle: f64) A2tfResult {
        var sign: u8 = undefined;
        var ihmsf: [4]c_int = undefined;
        c.eraA2tf(ndp, angle, &sign, &ihmsf);
        return .{
            .sign = sign,
            .hours = ihmsf[0],
            .minutes = ihmsf[1],
            .seconds = ihmsf[2],
            .fraction = ihmsf[3],
        };
    }
};

/// Cartesian and spherical coordinates of the same vector.
pub const spherical = struct {
    /// The two angles of a Cartesian direction.
    ///
    /// See `SphericalAngles` for the ranges: `eraC2s` does not normalise, and
    /// both angles are `0.0` for a zero vector.
    pub fn fromCartesian(p: *const Vec3) SphericalAngles {
        var theta: f64 = undefined;
        var phi: f64 = undefined;
        c.eraC2s(@constCast(p), &theta, &phi);
        return .{ .theta = theta, .phi = phi };
    }

    /// The two angles and the modulus of a Cartesian point.
    pub fn cartesianToSpherical(p: *const Vec3) CartesianSpherical {
        var theta: f64 = undefined;
        var phi: f64 = undefined;
        var radius: f64 = undefined;
        c.eraP2s(@constCast(p), &theta, &phi, &radius);
        return .{ .theta = theta, .phi = phi, .radius = radius };
    }

    /// The two angles, the modulus and the three rates of a position and a
    /// velocity.
    ///
    /// See `PvSpherical` for what each rate is. Upstream returns no status.
    pub fn pvToSpherical(pv: Pv) PvSpherical {
        var theta: f64 = undefined;
        var phi: f64 = undefined;
        var radius: f64 = undefined;
        var theta_rate: f64 = undefined;
        var phi_rate: f64 = undefined;
        var radius_rate: f64 = undefined;
        c.eraPv2s(
            pvPointer(&pv),
            &theta,
            &phi,
            &radius,
            &theta_rate,
            &phi_rate,
            &radius_rate,
        );
        return .{
            .theta = theta,
            .phi = phi,
            .radius = radius,
            .theta_rate = theta_rate,
            .phi_rate = phi_rate,
            .radius_rate = radius_rate,
        };
    }

    /// The unit vector at the two angles.
    ///
    /// Upstream does not normalise its arguments (`src/s2c.c:6-9`), so a
    /// `phi` outside `[-pi/2, pi/2]` gives a vector that is not a unit vector.
    pub fn toCartesian(theta: f64, phi: f64) Vec3 {
        var vector: Vec3 = undefined;
        c.eraS2c(theta, phi, &vector);
        return vector;
    }

    /// The vector at the two angles with the given modulus.
    pub fn toCartesianWithRadius(theta: f64, phi: f64, radius: f64) Vec3 {
        var vector: Vec3 = undefined;
        c.eraS2p(theta, phi, radius, &vector);
        return vector;
    }

    /// The position and velocity at the two angles, the modulus and the three
    /// rates. Upstream returns no status.
    pub fn toPv(
        theta: f64,
        phi: f64,
        radius: f64,
        theta_rate: f64,
        phi_rate: f64,
        radius_rate: f64,
    ) Pv {
        var pv: Pv = undefined;
        c.eraS2pv(theta, phi, radius, theta_rate, phi_rate, radius_rate, pvPointer(&pv));
        return pv;
    }
};

/// Azimuth and elevation against hour angle and declination, at a latitude.
///
/// These are the two forms every observing programme carries, and neither
/// routine validates an argument or returns a status. Azimuth here is north
/// zero and east 90 degrees, and `hd2ae` returns it in `[0, 2*pi)`.
pub const horizon = struct {
    /// Azimuth and elevation to hour angle and declination.
    ///
    /// `latitude` is the geodetic latitude of the observer. The hour angle is
    /// west positive and the declination is what the same routine calls the
    /// "declination" of the line of sight. Upstream writes `0.0` for the hour
    /// angle when the horizontal projection vanishes, i.e. exactly at a pole
    /// (`src/ae2hd.c:20-21`), and that case is preserved rather than turned
    /// into an error.
    pub fn azimuthElevationToHorizontal(azimuth: f64, elevation: f64, latitude: f64) ObservedSpherical {
        var hour_angle: f64 = undefined;
        var declination: f64 = undefined;
        c.eraAe2hd(azimuth, elevation, latitude, &hour_angle, &declination);
        return .{ .first = hour_angle, .second = declination };
    }

    /// Hour angle and declination to azimuth and elevation.
    ///
    /// `azimuth` is in `[0, 2*pi)` and `elevation` is in `[-pi/2, pi/2]`. As in
    /// the forward direction, an exactly polar line of sight gives `0.0` for
    /// the azimuth (`src/hd2ae.c:19-20`).
    pub fn horizontalToAzimuthElevation(hour_angle: f64, declination: f64, latitude: f64) ObservedSpherical {
        var azimuth: f64 = undefined;
        var elevation: f64 = undefined;
        c.eraHd2ae(hour_angle, declination, latitude, &azimuth, &elevation);
        return .{ .first = azimuth, .second = elevation };
    }

    /// The parallax of a line of sight at hour angle and declination, radians.
    ///
    /// This is `atan2(sin(ha) cos(phi), sin(phi) cos(dec) - cos(phi) sin(dec)
    /// cos(ha))`, and upstream returns exactly `0.0` when both numerator terms
    /// are zero (`src/hd2pa.c:12-13`) rather than an undefined angle.
    pub fn horizontalToParallax(hour_angle: f64, declination: f64, latitude: f64) f64 {
        return c.eraHd2pa(hour_angle, declination, latitude);
    }
};

/// Ecliptic and equatorial coordinates in the IAU 2006 model.
///
/// Upstream takes the date as a TDB two-part Julian Date and returns no
/// status. The matrix form `ecm06` is the one the other two are built from, so
/// a caller who needs the rotation itself takes that instead.
pub const ecliptic = struct {
    /// Ecliptic longitude and latitude to ICRS right ascension and declination.
    pub fn fromEcliptic(date: Date2, position: EclipticCoordinates) EquatorialCoordinates {
        var right_ascension: f64 = undefined;
        var declination: f64 = undefined;
        c.eraEceq06(date.part_a, date.part_b, position.longitude, position.latitude, &right_ascension, &declination);
        return .{ .right_ascension = right_ascension, .declination = declination };
    }

    /// The ICRS-to-ecliptic rotation matrix at a date.
    pub fn matrix(date: Date2) Mat3 {
        var icrs_to_ecliptic: Mat3 = undefined;
        c.eraEcm06(date.part_a, date.part_b, &icrs_to_ecliptic);
        return icrs_to_ecliptic;
    }

    /// ICRS right ascension and declination to ecliptic longitude and latitude.
    pub fn toEcliptic(date: Date2, position: EquatorialCoordinates) EclipticCoordinates {
        var longitude: f64 = undefined;
        var latitude: f64 = undefined;
        c.eraEqec06(date.part_a, date.part_b, position.right_ascension, position.declination, &longitude, &latitude);
        return .{ .longitude = longitude, .latitude = latitude };
    }
};

/// A pair of spherical coordinates named only by its two angles, so that a
/// frame this module does not wrap is not mislabelled as one it does.
pub const SphericalPair = struct {
    /// The first angle, radians. For `galactic` this is the longitude.
    longitude: f64,
    /// The second angle, radians. For `galactic` this is the latitude.
    latitude: f64,
};

/// Galactic and ICRS coordinates.
///
/// The rotation is a fixed matrix compiled into upstream's source
/// (`src/g2icrs.c:6-11`), not a dated model, so neither routine takes a date.
/// Both normalise their outputs with `eraAnp` and `eraAnpm` respectively
/// (`src/g2icrs.c:20-21`).
pub const galactic = struct {
    /// Galactic longitude and latitude to ICRS right ascension and declination.
    pub fn toIcrs(longitude: f64, latitude: f64) EquatorialCoordinates {
        var right_ascension: f64 = undefined;
        var declination: f64 = undefined;
        c.eraG2icrs(longitude, latitude, &right_ascension, &declination);
        return .{ .right_ascension = right_ascension, .declination = declination };
    }

    /// ICRS right ascension and declination to galactic longitude and latitude.
    pub fn fromIcrs(right_ascension: f64, declination: f64) SphericalPair {
        var longitude: f64 = undefined;
        var latitude: f64 = undefined;
        c.eraIcrs2g(right_ascension, declination, &longitude, &latitude);
        return .{ .longitude = longitude, .latitude = latitude };
    }
};

/// The gnomonic, or tangent plane, projection about a reference point.
///
/// This is the projection a photographic plate or a small field uses: the
/// projected coordinates are locally tangent, so they are not angles and the
/// inverse needs the reference point back. `xi` and `eta` are radians. Four of
/// the six routines return a condition report rather than failing, and what
/// that report counts differs by pair - solutions for `tpors`/`tporv`, a clamped
/// divisor for `tpxes`/`tpxev` - so each says what its own integer is. Upstream
/// returns no status at all from `tpsts` and `tpstv`.
pub const gnomonic = struct {
    /// Standard coordinates to the two tangent plane solutions.
    ///
    /// `first` and `second` are the two intersection points of the line of
    /// sight with the plane; which one a caller wants is a matter of the field,
    /// not of the algorithm. See `TporsResult` for what the count means, and
    /// note that a count of `0` writes nothing at all (`src/tpors.c:115-117`).
    pub fn fromStandardCoordinates(xi: f64, eta: f64, position: StandardCoordinates) TporsResult {
        var a01: f64 = undefined;
        var b01: f64 = undefined;
        var a02: f64 = undefined;
        var b02: f64 = undefined;
        const status: Status = .{ .value = c.eraTpors(
            xi,
            eta,
            position.a,
            position.b,
            &a01,
            &b01,
            &a02,
            &b02,
        ) };
        if (status.value == 0) return .{ .status = status, .first = null, .second = null };
        return .{
            .status = status,
            .first = .{ .a = a01, .b = b01 },
            .second = .{ .a = a02, .b = b02 },
        };
    }

    /// The tangent plane coordinates of a Cartesian direction, giving both
    /// solutions.
    ///
    /// See `fromStandardCoordinates` and `TporvResult`; a count of `0` writes
    /// nothing (`src/tporv.c:112-114`).
    pub fn fromVector(xi: f64, eta: f64, direction: *const Vec3) TporvResult {
        var v01: Vec3 = undefined;
        var v02: Vec3 = undefined;
        const status: Status = .{ .value = c.eraTporv(xi, eta, @constCast(direction), &v01, &v02) };
        if (status.value == 0) return .{ .status = status, .first = null, .second = null };
        return .{ .status = status, .first = v01, .second = v02 };
    }

    /// The standard coordinates at tangent plane coordinates `(xi, eta)` from a
    /// reference point `(a0, b0)`.
    ///
    /// Upstream normalises `a` into `[0, 2*pi)` and returns no status
    /// (`src/tpsts.c:10-11`).
    pub fn toStandardCoordinates(xi: f64, eta: f64, reference: StandardCoordinates) StandardCoordinates {
        var a: f64 = undefined;
        var b: f64 = undefined;
        c.eraTpsts(xi, eta, reference.a, reference.b, &a, &b);
        return .{ .a = a, .b = b };
    }

    /// The Cartesian direction at tangent plane coordinates `(xi, eta)` from a
    /// reference direction.
    ///
    /// Upstream returns no status, and it is not normalised: the vector is
    /// scaled so that its component along the reference direction matches
    /// `v0`'s length (`src/tpstv.c:14-24`).
    pub fn toVector(xi: f64, eta: f64, reference: *const Vec3) Vec3 {
        var vector: Vec3 = undefined;
        c.eraTpstv(xi, eta, @constCast(reference), &vector);
        return vector;
    }

    /// Standard coordinates to tangent plane coordinates about a reference
    /// point.
    pub fn fromStandardCoordinatesInverse(position: StandardCoordinates, reference: StandardCoordinates) TpxeResult {
        var xi: f64 = undefined;
        var eta: f64 = undefined;
        const status: Status = .{ .value = c.eraTpxes(
            position.a,
            position.b,
            reference.a,
            reference.b,
            &xi,
            &eta,
        ) };
        return .{ .status = status, .coordinates = .{ .a = xi, .b = eta } };
    }

    /// A Cartesian direction to tangent plane coordinates about a reference
    /// direction.
    pub fn fromVectorInverse(direction: *const Vec3, reference: *const Vec3) TpxeResult {
        var xi: f64 = undefined;
        var eta: f64 = undefined;
        const status: Status = .{ .value = c.eraTpxev(
            @constCast(direction),
            @constCast(reference),
            &xi,
            &eta,
        ) };
        return .{ .status = status, .coordinates = .{ .a = xi, .b = eta } };
    }
};

/// The atmospheric refraction model.
pub const atmosphere = struct {
    /// The two refraction constants for the observing conditions.
    ///
    /// The arguments are upstream's, unchanged: pressure at the observer in
    /// mbar, ambient temperature in degrees Celsius, relative humidity as a
    /// fraction, and the observing wavelength in micrometres
    /// (`src/refco.c:20-23`). Upstream applies no bounds and returns no status.
    pub fn refractionConstants(
        pressure_mbar: f64,
        temperature_c: f64,
        humidity: f64,
        wavelength_um: f64,
    ) RefractionConstants {
        var refa: f64 = undefined;
        var refb: f64 = undefined;
        c.eraRefco(pressure_mbar, temperature_c, humidity, wavelength_um, &refa, &refb);
        return .{ .a = refa, .b = refb };
    }
};

/// A star's position and proper motion with no parallax and no radial
/// velocity, which is what the two catalogue epoch transformations produce.
pub const StarMotionReduced = struct {
    /// Right ascension, radians.
    right_ascension: f64,
    /// Declination, radians.
    declination: f64,
    /// Proper motion in right ascension, radians per Julian year.
    pm_ra: f64,
    /// Proper motion in declination, radians per Julian year.
    pm_dec: f64,
};

/// The transformations between the B1950.0 FK4 system, the J2000.0 FK5 system
/// and the Hipparcos system.
///
/// None of them returns a status. FK4 is a much older system than FK5 and the
/// two are related by an E-terms model that upstream compiles into its own
/// source rather than reading from data (`src/fk45z.c:8-12`), so these
/// transformations are the IERS-era models at this pin and not a rederivation
/// of anything current. Angles are radians, proper motions radians per Julian
/// year, parallax arcseconds and radial velocity km/s.
pub const starCatalogs = struct {
    /// FK4 B1950.0 to FK5 J2000.0, moving the proper motion as well.
    pub fn fk4ToFk5(entry: StarMotion) StarMotion {
        var r2000: f64 = undefined;
        var d2000: f64 = undefined;
        var dr2000: f64 = undefined;
        var dd2000: f64 = undefined;
        var p2000: f64 = undefined;
        var v2000: f64 = undefined;
        c.eraFk425(
            entry.right_ascension,
            entry.declination,
            entry.pm_ra,
            entry.pm_dec,
            entry.parallax,
            entry.radial_velocity,
            &r2000,
            &d2000,
            &dr2000,
            &dd2000,
            &p2000,
            &v2000,
        );
        return .{
            .right_ascension = r2000,
            .declination = d2000,
            .pm_ra = dr2000,
            .pm_dec = dd2000,
            .parallax = p2000,
            .radial_velocity = v2000,
        };
    }

    /// FK4 B1950.0 to FK5 J2000.0 for a position only.
    ///
    /// `bepoch` is the Besselian epoch of the FK4 position as a year with
    /// fraction, which is what upstream's own argument block calls it
    /// (`src/fk45z.c:23`). Upstream reads it twice: as the raw offset from
    /// B1950.0 at `src/fk45z.c:122`, and through `eraEpb2jd`/`eraEpj` as a
    /// Besselian epoch turned into a Julian epoch (`:141-142`). No
    /// `eraCal2jd` is involved. Upstream's note 1 records that a Julian epoch
    /// may be supplied in its place because the difference is negligible
    /// (`:30-32`).
    pub fn fk4ToFk5Position(right_ascension: f64, declination: f64, bepoch: f64) EquatorialCoordinates {
        var r2000: f64 = undefined;
        var d2000: f64 = undefined;
        c.eraFk45z(right_ascension, declination, bepoch, &r2000, &d2000);
        return .{ .right_ascension = r2000, .declination = d2000 };
    }

    /// FK5 J2000.0 to FK4 B1950.0, moving the proper motion as well.
    pub fn fk5ToFk4(entry: StarMotion) StarMotion {
        var r1950: f64 = undefined;
        var d1950: f64 = undefined;
        var dr1950: f64 = undefined;
        var dd1950: f64 = undefined;
        var p1950: f64 = undefined;
        var v1950: f64 = undefined;
        c.eraFk524(
            entry.right_ascension,
            entry.declination,
            entry.pm_ra,
            entry.pm_dec,
            entry.parallax,
            entry.radial_velocity,
            &r1950,
            &d1950,
            &dr1950,
            &dd1950,
            &p1950,
            &v1950,
        );
        return .{
            .right_ascension = r1950,
            .declination = d1950,
            .pm_ra = dr1950,
            .pm_dec = dd1950,
            .parallax = p1950,
            .radial_velocity = v1950,
        };
    }

    /// FK5 J2000.0 to FK4 B1950.0 for a position and a proper motion.
    ///
    /// `bepoch` is as for `fk4ToFk5Position`. Upstream drops the parallax and
    /// the radial velocity on the way in (`src/fk54z.c:6-8`), so they do not
    /// come back and this returns four numbers rather than six.
    pub fn fk5ToFk4Position(
        right_ascension: f64,
        declination: f64,
        bepoch: f64,
    ) StarMotionReduced {
        var r1950: f64 = undefined;
        var d1950: f64 = undefined;
        var dr1950: f64 = undefined;
        var dd1950: f64 = undefined;
        c.eraFk54z(right_ascension, declination, bepoch, &r1950, &d1950, &dr1950, &dd1950);
        return .{
            .right_ascension = r1950,
            .declination = d1950,
            .pm_ra = dr1950,
            .pm_dec = dd1950,
        };
    }

    /// FK5 J2000.0 to Hipparcos, `eraFk52h`.
    ///
    /// Upstream builds this from `eraStarpv` and `eraFk5hip`, so the parallax
    /// and the radial velocity are moved too, and the `+1`/`+2` warnings
    /// `starpv` raises for a tiny parallax or an excessive velocity are
    /// **not** propagated: `eraFk52h` discards the status
    /// (`src/fk52h.c:9`). A caller who needs to know whether the parallax was
    /// clamped calls `vectors.starpv` on the same input first.
    pub fn fk5ToHipparcos(entry: StarMotion) StarMotion {
        var rh: f64 = undefined;
        var dh: f64 = undefined;
        var drh: f64 = undefined;
        var ddh: f64 = undefined;
        var pxh: f64 = undefined;
        var rvh: f64 = undefined;
        c.eraFk52h(
            entry.right_ascension,
            entry.declination,
            entry.pm_ra,
            entry.pm_dec,
            entry.parallax,
            entry.radial_velocity,
            &rh,
            &dh,
            &drh,
            &ddh,
            &pxh,
            &rvh,
        );
        return .{
            .right_ascension = rh,
            .declination = dh,
            .pm_ra = drh,
            .pm_dec = ddh,
            .parallax = pxh,
            .radial_velocity = rvh,
        };
    }

    /// Hipparcos to FK5 J2000.0, `eraH2fk5`.
    ///
    /// As `fk5ToHipparcos`, the status of the internal `eraStarpv` is discarded
    /// (`src/h2fk5.c:9`).
    pub fn hipparcosToFk5(entry: StarMotion) StarMotion {
        var r5: f64 = undefined;
        var d5: f64 = undefined;
        var dr5: f64 = undefined;
        var dd5: f64 = undefined;
        var px5: f64 = undefined;
        var rv5: f64 = undefined;
        c.eraH2fk5(
            entry.right_ascension,
            entry.declination,
            entry.pm_ra,
            entry.pm_dec,
            entry.parallax,
            entry.radial_velocity,
            &r5,
            &d5,
            &dr5,
            &dd5,
            &px5,
            &rv5,
        );
        return .{
            .right_ascension = r5,
            .declination = d5,
            .pm_ra = dr5,
            .pm_dec = dd5,
            .parallax = px5,
            .radial_velocity = rv5,
        };
    }

    /// The rotation and E-terms vector the Hipparcos transformations use,
    /// `eraFk5hip`.
    ///
    /// Both are constants compiled into upstream's source
    /// (`src/fk5hip.c:9-18`), so this computes the same pair every time and
    /// exists for a caller who wants to apply the rotation themselves.
    pub fn hipparcosConstants() Fk5HipResult {
        var b5_to_fk5: Mat3 = undefined;
        var spin: Vec3 = undefined;
        c.eraFk5hip(&b5_to_fk5, &spin);
        return .{ .rotation = b5_to_fk5, .spin = spin };
    }

    /// FK5 J2000.0 at an epoch to the same system at a date, `eraFk5hz`.
    ///
    /// `date` is a TDB two-part Julian Date; upstream measures the interval
    /// from J2000.0 in Julian years (`src/fk5hz.c:9`) and applies the
    /// E-terms as a rotation over that interval. Only the position comes back.
    pub fn fk5ToHipparcosAtDate(right_ascension: f64, declination: f64, date: Date2) EquatorialCoordinates {
        var rh: f64 = undefined;
        var dh: f64 = undefined;
        c.eraFk5hz(right_ascension, declination, date.part_a, date.part_b, &rh, &dh);
        return .{ .right_ascension = rh, .declination = dh };
    }

    /// Hipparcos at a date to FK5 J2000.0, `eraHfk5z`.
    ///
    /// `date` is as for `fk5ToHipparcosAtDate`, and only four numbers come
    /// back because the parallax is not transformed by this routine.
    pub fn hipparcosToFk5AtDate(
        right_ascension: f64,
        declination: f64,
        date: Date2,
    ) StarMotionReduced {
        var r5: f64 = undefined;
        var d5: f64 = undefined;
        var dr5: f64 = undefined;
        var dd5: f64 = undefined;
        c.eraHfk5z(right_ascension, declination, date.part_a, date.part_b, &r5, &d5, &dr5, &dd5);
        return .{
            .right_ascension = r5,
            .declination = d5,
            .pm_ra = dr5,
            .pm_dec = dd5,
        };
    }
};

/// The fourteen fundamental arguments of the IERS Conventions (2003), which are
/// the periodic building blocks the precession-nutation models are written in.
///
/// `t` is Julian centuries of TDB since J2000.0 in every one of them, and every
/// result is an angle in radians. Upstream returns no status and normalises
/// nothing: each function returns its own polynomial's value, so a caller who
/// wants an angle in `[0, 2*pi)` normalises with `angles.anp`.
pub const fundamentalArgs = struct {
    /// `D`, the mean elongation of the Moon from the Sun (`src/fad03.c`).
    pub fn d(t: f64) f64 {
        return c.eraFad03(t);
    }

    /// `L'`, the mean longitude of Earth (`src/fae03.c`).
    pub fn earthLongitude(t: f64) f64 {
        return c.eraFae03(t);
    }

    /// `F`, the mean longitude of the Moon minus the mean longitude of its
    /// ascending node (`src/faf03.c`).
    pub fn f(t: f64) f64 {
        return c.eraFaf03(t);
    }

    /// `J`, the mean longitude of Jupiter (`src/faju03.c`).
    pub fn jupiterLongitude(t: f64) f64 {
        return c.eraFaju03(t);
    }

    /// `l`, the mean anomaly of the Moon (`src/fal03.c`).
    pub fn moonAnomaly(t: f64) f64 {
        return c.eraFal03(t);
    }

    /// `l'`, the mean anomaly of the Sun (`src/falp03.c`).
    pub fn sunAnomaly(t: f64) f64 {
        return c.eraFalp03(t);
    }

    /// `l''`, the mean longitude of Mars (`src/fama03.c`).
    pub fn marsLongitude(t: f64) f64 {
        return c.eraFama03(t);
    }

    /// `l'''`, the mean longitude of Mercury (`src/fame03.c`).
    pub fn mercuryLongitude(t: f64) f64 {
        return c.eraFame03(t);
    }

    /// `L''`, the mean longitude of Neptune (`src/fane03.c`).
    pub fn neptuneLongitude(t: f64) f64 {
        return c.eraFane03(t);
    }

    /// `Omega`, the mean longitude of the Moon's ascending node (`src/faom03.c`).
    pub fn moonNode(t: f64) f64 {
        return c.eraFaom03(t);
    }

    /// `p`, the general accumulated precession in longitude (`src/fapa03.c`).
    pub fn accumulatedPrecession(t: f64) f64 {
        return c.eraFapa03(t);
    }

    /// `L'`, the mean longitude of Saturn, in the same symbol as `earthLongitude`
    /// but a different body (`src/fasa03.c`).
    pub fn saturnLongitude(t: f64) f64 {
        return c.eraFasa03(t);
    }

    /// `U`, the mean longitude of Uranus (`src/faur03.c`).
    pub fn uranusLongitude(t: f64) f64 {
        return c.eraFaur03(t);
    }

    /// `V`, the mean longitude of Venus (`src/fave03.c`).
    pub fn venusLongitude(t: f64) f64 {
        return c.eraFave03(t);
    }
};
