//! Zig facade over ERFA's C implementation; `c` exposes the translated headers.
//!
//! Typed functions preserve upstream status codes and represent unwritten outputs as `null`.
//! `Date2` preserves upstream's two-part split; `sum` is a convenience, not a canonical form.
//!
//! Leap-second setters retain caller memory. Keep it alive until replacement or reset; table
//! storage is thread-local only when the target's `ERFA_THREAD_LOCAL` macro selects it.
//!
//! The facade allocates nothing. Linked builds call the compiled library directly; runtime
//! builds require `load` before use, keep the provider for process lifetime, and do not fall
//! back to another provider.
//!
//! Import the facade as `@import("erfa")`; `c` exposes the raw translated C declarations.

const std = @import("std");

/// Translated upstream headers or their runtime dispatch, with raw declarations and constants.
/// Direct C calls retain upstream behavior and caller obligations.
pub const c = @import("c");

// Linked-build loader core; runtime dispatch provides its own declarations.
const rt = @import("rt");

/// Whether native symbols resolve through the runtime loader.
pub const runtime_loaded: bool = if (@hasDecl(c, "rt_runtime_loaded")) c.rt_runtime_loaded else false;

/// Runtime provider: explicit file path or platform-loader name, with no fallback.
pub const LoadSource = if (runtime_loaded) c.LoadSource else rt.LoadSource;

/// Errors returned by `load`.
pub const LoadError = if (runtime_loaded) c.LoadError else rt.LoadError;

/// Resolve the runtime provider; same-source repeats are idempotent, different sources fail, and failed attempts can be retried.
/// Concurrent calls share a result; re-entry errors. The handle lasts to process exit; linked builds panic.
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

/// Return the retained runtime request, or `null` when unloaded or linked.
pub fn loadedSource() ?LoadSource {
    if (comptime !runtime_loaded) return null;
    return c.loadedSource();
}

/// Upstream status: zero is success, positive is warning, negative is error.
pub const Status = struct {
    /// The signed integer upstream returned, unaltered.
    value: i32,

    /// The status of a call that reported nothing.
    pub const ok: Status = .{ .value = 0 };

    /// True when upstream reported neither a warning nor an error.
    pub fn isOk(self: Status) bool {
        return self.value == 0;
    }

    /// True when upstream reports a warning; warning outputs remain usable.
    pub fn isWarning(self: Status) bool {
        return self.value > 0;
    }

    /// True when upstream reports an error; output availability is function-specific.
    pub fn isError(self: Status) bool {
        return self.value < 0;
    }

    pub fn format(self: Status, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("erfa.Status({d})", .{self.value});
    }
};

/// A two-part Julian Date. Preserve the split; the second part is not normalized.
pub const Date2 = struct {
    /// First Julian Date part, such as the MJD zero point or J2000 split.
    part_a: f64,

    /// Second, unnormalized Julian Date part; it may exceed one or be negative.
    part_b: f64,

    /// Return `part_a + part_b`; UTC and UT1 differences are not precise intervals.
    pub fn sum(self: Date2) f64 {
        return self.part_a + self.part_b;
    }
};

/// Time scales accepted by the facade; `.utc` selects leap-second handling.
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

    /// Return the NUL-terminated C code for this time scale.
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

/// Reference ellipsoids supported by upstream, using its identifiers.
pub const Ellipsoid = enum(c_int) {
    /// World Geodetic System 1984.
    wgs84 = c.ERFA_WGS84,
    /// GRS80.
    grs80 = c.ERFA_GRS80,
    /// World Geodetic System 1972.
    wgs72 = c.ERFA_WGS72,

    /// Return the C identifier used by the ellipsoid routines.
    pub fn id(self: Ellipsoid) c_int {
        return @backingInt(self);
    }
};

/// Coordinate representation for observed-angle conversions.
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

/// The upstream `eraLEAPSECOND` record layout.
pub const LeapSecond = c.eraLEAPSECOND;

/// Star-independent astrometry values written by `eraApco13`; `phi` is omitted.
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
    /// Diurnal aberration; `eraApco` sets zero and `eraApio` computes it.
    diurab: f64,
    /// The local Earth rotation angle, radians.
    eral: f64,
    /// Refraction constant A, radians.
    refa: f64,
    /// Refraction constant B, radians.
    refb: f64,
};

/// The nine astrometry fields written by `eraApio`.
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

// Copy the initialized fields; upstream does not assign `phi`.
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

// Copy only the fields assigned by `eraApio`.
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

/// Gregorian date fields without a time of day.
pub const CalendarDate = struct {
    /// Proleptic Gregorian year; `eraCal2jd` rejects values below -4799.
    year: i32,
    /// Month, 1 to 12.
    month: i32,
    /// Day of month, validated against the month's length.
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

    /// Fraction of the day, normalized to `[0, 1)` by `eraJd2cal`.
    fraction: f64,
};

/// Gregorian date with a rounded fraction from `eraJdcalf`.
pub const RoundedCalendarDate = struct {
    /// See `CalendarDate.year`.
    year: i32,
    /// See `CalendarDate.month`.
    month: i32,
    /// See `CalendarDate.day`.
    day: i32,

    /// Fraction in units of `10^-ndp`; rounding may produce the denominator.
    fraction: i32,
};

/// A time of day broken into fields, from `eraD2dtf` or `eraD2tf`.
pub const TimeOfDay = struct {
    /// Hour, normally 0-23; coarse rounding can produce 24.
    hour: i32,
    /// Minutes, 0 to 59.
    minute: i32,
    /// Second, 0-59 or 60 at a UTC leap second.
    second: i32,
    /// Fraction of a second in units of `10^-ndp`, not normalized.
    fraction: i32,
};

/// Two observed angles used by coordinate conversions.
pub const ObservedSpherical = struct {
    /// Right ascension or hour angle, radians; hour angle is west-positive.
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

/// IAU 1976 precession angles, in radians.
pub const Prec76Angles = struct {
    /// Accumulated precession in longitude.
    zeta: f64,
    /// Accumulated precession in longitude, the second of the two.
    z: f64,
    /// Accumulated precession in obliquity.
    theta: f64,
};

/// Rotation matrices and angles returned by precession-nutation routines.
pub const PrecessionNutation = struct {
    /// Nutation in longitude, radians; some models take it as input.
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

/// Position and velocity in upstream's `double pv[2][3]` ABI layout.
/// The compile-time check below validates direct C passing without a copy.
pub const Pv = extern struct {
    /// Position, in au.
    position: Vec3,
    /// Velocity, in au/day.
    velocity: Vec3,
};

comptime {
    // Ensure `Pv` matches upstream's `double [2][3]` layout on this target.
    if (@sizeOf(Pv) != 2 * @sizeOf(Vec3) or @alignOf(Pv) != @alignOf(Vec3)) {
        @compileError("erfa: Pv no longer has the layout of double [2][3]");
    }
}

/// Reinterpret `Pv` as `double [2][3]`; callers use this for read-only C inputs.
/// `pvstar` receives a mutable copy because upstream changes its velocity member.
inline fn pvPointer(pv: *const Pv) [*c][3]f64 {
    return @constCast(@ptrCast(pv));
}

/// Result of a date conversion; `date` is absent when upstream writes no output.
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
    /// Absent for `-1` and `-2`; `-3` retains the computed date.
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
    /// Absent for negative status; warnings retain the computed date.
    date: ?Date2,
};

/// The result of `calendar.d2dtf`.
pub const D2dtfResult = struct {
    /// `+1` dubious year, `0` OK, `-1` unacceptable date.
    status: Status,
    /// The calendar date, or `null` when the status is `-1`.
    date: ?CalendarDate,
    /// Time of day, absent on `-1`; the seconds field may be 60 at a leap second.
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
    /// Zero on success; positive status identifies the first out-of-range field.
    status: Status,
    /// Interval in days, computed even when a range check fails.
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
    /// Zero on success; positive status identifies the out-of-range field.
    status: Status,
    /// The angle in radians, computed even when a range check fails.
    radians: f64,
};

/// The result of `timescale.dat`.
pub const DatResult = struct {
    /// `+1` dubious year, `0` OK, `-1` to `-5` errors.
    status: Status,
    /// TAI minus UTC in seconds; upstream returns zero when no result is valid.
    delta_at: f64,
};

/// The result of `geodetic.eform`.
pub const EformResult = struct {
    /// `0` OK, `-1` illegal identifier.
    status: Status,
    /// Equatorial radius in metres; upstream returns zero on `-1`.
    equatorial_radius: f64,
    /// Flattening; upstream returns zero for an illegal identifier.
    flattening: f64,
};

/// Geodetic longitude, latitude and height.
pub const Geodetic = struct {
    /// Longitude, radians, east positive.
    longitude: f64,
    /// Geodetic latitude, radians.
    latitude: f64,
    /// Height above the ellipsoid, in metres.
    height: f64,
};

/// The result of `geodetic.gc2gd`.
pub const Gc2gdResult = struct {
    /// `0` OK, `-1` illegal identifier, `-2` internal error.
    status: Status,
    /// Always present; upstream writes `-1e9` to each field on error.
    geodetic: Geodetic,
};

/// The result of `geodetic.gc2gde`.
pub const Gc2gdeResult = struct {
    /// `0` OK, `-1` illegal flattening, `-2` illegal radius.
    status: Status,
    /// Absent on negative status; upstream leaves the output untouched.
    geodetic: ?Geodetic,
};

/// The result of `geodetic.gd2gc`.
pub const Gd2gcResult = struct {
    /// `0` OK, `-1` illegal identifier, `-2` illegal case.
    status: Status,
    /// Always present; upstream returns a zero vector on error.
    cartesian: Vec3,
};

/// The result of `geodetic.gd2gce`.
pub const Gd2gceResult = struct {
    /// `-1` guards a non-positive divisor; no finite double input reaches it.
    status: Status,
    /// Absent on negative status; upstream leaves the output untouched.
    cartesian: ?Vec3,
};

/// The result of `rotation.apco13`.
pub const Apco13Result = struct {
    /// `+1` dubious year, `0` OK, `-1` unacceptable date.
    status: Status,
    /// Astrometry parameters, absent on `-1`.
    astrom: ?Astrom,
    /// ERA minus GST in radians, absent on `-1`; this is not the equation of equinoxes.
    equation_of_origins: ?f64,
};

/// The result of `rotation.apio13`.
pub const Apio13Result = struct {
    /// `+1` dubious year, `0` OK, `-1` unacceptable date.
    status: Status,
    /// CIRS-to-observed parameters, absent on `-1`.
    astrom: ?ObservedAstrom,
};

/// The result of `rotation.atco13`.
pub const Atco13Result = struct {
    /// `+1` dubious year, `0` OK, `-1` unacceptable date.
    status: Status,
    /// Observed place, absent on `-1`.
    place: ?ObservedPlace,
    /// Equation of origins (ERA minus GST), absent on `-1`.
    equation_of_origins: ?f64,
};

/// The result of `rotation.atio13`.
pub const Atio13Result = struct {
    /// `+1` dubious year, `0` OK, `-1` unacceptable date.
    status: Status,
    /// Observed place, absent on `-1`.
    place: ?ObservedPlace,
};

/// The result of `rotation.atoc13`.
pub const Atoc13Result = struct {
    /// `+1` dubious year, `0` OK, `-1` unacceptable date.
    status: Status,
    /// ICRS right ascension and declination, absent on `-1`.
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
    /// Zero on success; `+1` reports a date outside 1900-2100.
    status: Status,
    /// Heliocentric Earth position (au) and velocity (au/day).
    heliocentric: Pv,
    /// Barycentric Earth position (au) and velocity (au/day).
    barycentric: Pv,
};

/// The result of `ephemeris.plan94`.
pub const Plan94Result = struct {
    /// `-1` invalid planet, `+1` year outside 1000-3000, `+2` no convergence.
    status: Status,
    /// Heliocentric J2000.0 position and velocity; zeroed on `-1`.
    pv: Pv,
};

/// Result of `vectors.pn`: input modulus and unit direction.
pub const PnResult = struct {
    /// The length of the input vector.
    modulus: f64,
    /// The input vector scaled to unit length. Zero when the input is zero.
    unit: Vec3,
};

/// The result of `leap.getLeapSeconds`.
pub const LeapTableResult = struct {
    /// Entry count, or `-1` for upstream's internal error.
    status: Status,
    /// Borrow of the active table, or `null` on `-1`.
    entries: ?[]const LeapSecond,
};

/// Access to upstream's leap-second table; `ERFA_THREAD_LOCAL` determines whether it is per-thread.
pub const leap = struct {
    /// Borrow the active table; it is initialized on first use and invalidated by replacement or reset.
    pub fn getLeapSeconds() LeapTableResult {
        var table: [*c]LeapSecond = undefined;
        const count = c.eraGetLeapSeconds(&table);
        const status: Status = .{ .value = count };
        if (status.isError()) return .{ .status = status, .entries = null };
        const length: usize = @intCast(count);
        return .{ .status = status, .entries = table[0..length] };
    }

    /// Retain `entries` until replacement or reset; `null` restores upstream's built-in table.
    /// Do not mutate it during calls; preserve the pre-1972 prefix used for historical drift.
    pub fn setLeapSeconds(entries: ?[]const LeapSecond) void {
        if (entries) |table| {
            c.eraSetLeapSeconds(@constCast(table.ptr), @intCast(table.len));
        } else {
            c.eraSetLeapSeconds(null, 0);
        }
    }

    /// Initialize from `builtin` only when no positive-count table is active; returns a borrowed table.
    /// An existing table wins; use `setLeapSeconds` to replace it.
    pub fn datini(builtin: ?[]const LeapSecond) LeapTableResult {
        var table: [*c]LeapSecond = undefined;
        const builtin_count: c_int = if (builtin) |entries| @intCast(entries.len) else 0;
        const builtin_pointer: [*c]const LeapSecond = if (builtin) |entries| entries.ptr else null;
        const count = c.eraDatini(builtin_pointer, builtin_count, &table);
        const status: Status = .{ .value = count };
        // A null C pointer has no borrowable storage, so return an absent slice.
        if (count <= 0) return .{ .status = status, .entries = null };
        const length: usize = @intCast(count);
        return .{ .status = status, .entries = table[0..length] };
    }
};

/// Proleptic Gregorian date and time conversion to and from two-part Julian Dates.
pub const calendar = struct {
    /// Convert a Gregorian date to MJD at 0 h.
    /// `-1`/`-2` leave `date` absent; `-3` reports an invalid day but retains it.
    pub fn cal2jd(year: i32, month: i32, day: i32) Cal2jdResult {
        var djm0: f64 = undefined;
        var djm: f64 = undefined;
        const status: Status = .{ .value = c.eraCal2jd(year, month, day, &djm0, &djm) };
        // Year/month errors leave outputs unwritten; an invalid day still has a computed date.
        if (status.value == -1 or status.value == -2) {
            return .{ .status = status, .date = null };
        }
        return .{ .status = status, .date = .{ .part_a = djm0, .part_b = djm } };
    }

    /// Convert a two-part Julian Date to Gregorian date and fraction; the split does not affect the result.
    /// Outside `[-68569.5, 1e9]`, status is `-1` and `date` is absent.
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

    /// Round the date's day fraction to `ndp` decimal places.
    /// Out-of-range `ndp` becomes zero with warning; values below 4 can overflow on 16-bit `int`.
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

    /// Convert calendar date and time to a two-part Julian Date; `.utc` selects leap-second handling.
    /// Warnings retain the date; `+2` or `+3` may leave `part_b` above 1.
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

    /// Convert a two-part Julian Date to calendar date and time at `ndp` precision.
    /// UTC leap seconds can produce second 60; coarse rounding may advance the day.
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

    /// Decompose days into sign and time fields; coarse rounding may produce hour 24.
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

    /// Convert time fields to days; range warnings retain the result and report the first invalid field.
    pub fn tf2d(sign: u8, hour: i32, minute: i32, second: f64) Tf2dResult {
        var days: f64 = undefined;
        const status: Status = .{ .value = c.eraTf2d(sign, hour, minute, second, &days) };
        return .{ .status = status, .days = days };
    }

    /// Convert time fields to radians; range warnings retain the computed angle.
    pub fn tf2a(sign: u8, hour: i32, minute: i32, second: f64) Tf2aResult {
        var radians: f64 = undefined;
        const status: Status = .{ .value = c.eraTf2a(sign, hour, minute, second, &radians) };
        return .{ .status = status, .radians = radians };
    }

    /// Convert degrees, arcminutes and arcseconds to radians; range warnings retain the result.
    pub fn af2a(sign: u8, degree: i32, arcminute: i32, arcsecond: f64) Af2aResult {
        var radians: f64 = undefined;
        const status: Status = .{ .value = c.eraAf2a(sign, degree, arcminute, arcsecond, &radians) };
        return .{ .status = status, .radians = radians };
    }

    /// Convert a two-part Julian Date to a Barycentric Dynamical Time Julian epoch.
    pub fn epb(date: Date2) f64 {
        return c.eraEpb(date.part_a, date.part_b);
    }

    /// Convert a Julian epoch to a two-part Julian Date in the MJD split.
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

/// Astronomical time-scale conversions; result types preserve status and absent outputs.
pub const timescale = struct {
    /// Return TAI-UTC seconds; `+1` may report a zero pre-1960 result or a computed dubious-year result.
    /// Negative status leaves `delta_at` zero.
    pub fn dat(year: i32, month: i32, day: i32, fraction_of_day: f64) DatResult {
        var delta: f64 = undefined;
        const status: Status = .{ .value = c.eraDat(year, month, day, fraction_of_day, &delta) };
        return .{ .status = status, .delta_at = delta };
    }

    /// Convert TAI to UTC; negative status leaves the date absent.
    pub fn taiutc(date: Date2) DateResult {
        var utc1: f64 = undefined;
        var utc2: f64 = undefined;
        const status: Status = .{ .value = c.eraTaiutc(date.part_a, date.part_b, &utc1, &utc2) };
        if (status.isError()) return .{ .status = status, .date = null };
        return .{ .status = status, .date = .{ .part_a = utc1, .part_b = utc2 } };
    }

    /// Convert UTC to TAI; propagate the dubious-year warning and leave the date absent on errors.
    pub fn utctai(date: Date2) DateResult {
        var tai1: f64 = undefined;
        var tai2: f64 = undefined;
        const status: Status = .{ .value = c.eraUtctai(date.part_a, date.part_b, &tai1, &tai2) };
        if (status.isError()) return .{ .status = status, .date = null };
        return .{ .status = status, .date = .{ .part_a = tai1, .part_b = tai2 } };
    }

    /// Convert UTC to UT1 using observed UT1-UTC seconds; negative status leaves the date absent.
    pub fn utcut1(date: Date2, delta_ut1: f64) DateResult {
        var ut11: f64 = undefined;
        var ut12: f64 = undefined;
        const status: Status = .{
            .value = c.eraUtcut1(date.part_a, date.part_b, delta_ut1, &ut11, &ut12),
        };
        if (status.isError()) return .{ .status = status, .date = null };
        return .{ .status = status, .date = .{ .part_a = ut11, .part_b = ut12 } };
    }

    /// Convert UT1 to UTC; tolerate imprecise UT1-UTC near leap seconds and return no date on errors.
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

    /// Estimate TDB-TT seconds for an Earth observer; `date` is TDB and distances are in kilometres.
    /// Longitude is in radians; the model is accurate to a few milliseconds.
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

/// Earth-rotation angles, sidereal times and observed-place transformations.
/// Sidereal routines return normalized angles without status; `ap*13`/`at*13` preserve status.
pub const rotation = struct {
    /// IAU 2000 Earth rotation angle for a UT1 date, radians in `[0, 2*pi)`.
    pub fn earthRotationAngle(date: Date2) f64 {
        return c.eraEra00(date.part_a, date.part_b);
    }

    /// IAU 2000 GMST from UT1 and TT, compatible with IAU 2000 precession-nutation and equinox models.
    pub fn gmst00(ut1: Date2, tt: Date2) f64 {
        return c.eraGmst00(ut1.part_a, ut1.part_b, tt.part_a, tt.part_b);
    }

    /// Greenwich mean sidereal time, IAU 2006 model, radians.
    pub fn gmst06(ut1: Date2, tt: Date2) f64 {
        return c.eraGmst06(ut1.part_a, ut1.part_b, tt.part_a, tt.part_b);
    }

    /// IAU 1982 GMST; not compatible with the IAU 2000 model family.
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

    /// IAU 2006 apparent sidereal time using a caller-supplied bias-precession-nutation matrix.
    /// Reads `rnpb`; use `gst06a` for the built-in IAU 2006A matrix.
    pub fn gst06(ut1: Date2, tt: Date2, rnpb: *const Mat3) f64 {
        return c.eraGst06(ut1.part_a, ut1.part_b, tt.part_a, tt.part_b, @constCast(rnpb));
    }

    /// Equation of the equinoxes from mean obliquity and nutation angle, radians.
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

    /// IAU 2000A equation of the equinoxes, including complementary terms.
    pub fn eect00(date: Date2) f64 {
        return c.eraEect00(date.part_a, date.part_b);
    }

    /// Prepare ICRS-to-observed astrometry and equation of origins from a UTC date and site.
    /// Site values are passed through without range checks.
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

    /// Prepare CIRS-to-observed astrometry from a UTC date and site.
    /// Returns only the nine fields upstream initializes; other `eraASTROM` fields are omitted.
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

    /// Convert ICRS position to observed place and equation of origins; proper motion is rad/year and parallax arcseconds.
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

/// Geodetic and geocentric conversions; upstream does not validate coordinate arguments.
pub const geodetic = struct {
    /// Return the radius and flattening of a reference ellipsoid; both are zero for an invalid identifier.
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

    /// Convert geocentric Cartesian metres to geodetic coordinates; errors retain the `-1e9` sentinel.
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

    /// Convert Cartesian metres to geodetic coordinates on a supplied ellipsoid; errors leave output absent.
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

    /// Convert geodetic coordinates to Cartesian; upstream does not validate inputs and zeroes output on error.
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

    /// Convert geodetic coordinates to Cartesian on a supplied ellipsoid.
    /// A non-positive divisor returns `-1` and leaves output absent.
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

/// Observing-site inputs for astrometry conversions; values use upstream units and are not range-checked.
pub const Observatory = struct {
    /// Observed UT1-UTC offset in seconds.
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
    /// Wavelength in micrometres; the air-to-vacuum transition is assumed at 0.55 um.
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

/// Precession, nutation and their rotation matrices; routines return no status.
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

    /// IAU 2006 equation of origins (ERA-GST), not the equation of the equinoxes.
    pub fn eo06a(date: Date2) f64 {
        return c.eraEo06a(date.part_a, date.part_b);
    }

    /// Compute equation of origins from `rnpb` and CIO locator `s` in radians.
    /// Reads `rnpb`; the result is ERA-GST, not the equation of the equinoxes.
    pub fn eors(rnpb: *const Mat3, cio_locator_s: f64) f64 {
        return c.eraEors(@constCast(rnpb), cio_locator_s);
    }

    /// CIP X and Y coordinates implied by Fukushima-Williams angles, radians.
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

    /// IAU 1976 precession angles from catalog epoch to date, radians.
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

    /// IAU 2000 precession-nutation from supplied nutation angles, returned unchanged.
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

    /// IAU 2006 precession-nutation from supplied nutation angles.
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

    /// IAU 2006/2000A precession-nutation with computed nutation angles.
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

    /// Polar motion matrix for `xp`, `yp` and the spurious `sp` term.
    pub fn pom00(polar_motion_x: f64, polar_motion_y: f64, spurious: f64) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraPom00(polar_motion_x, polar_motion_y, spurious, &matrix);
        return matrix;
    }

    /// ICRS-to-ecliptic Lieske matrix at an absolute TT Julian epoch, not years from J2000.
    pub fn ltecm(epoch: f64) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraLtecm(epoch, &matrix);
        return matrix;
    }

    /// Convert ICRS equatorial coordinates to ecliptic coordinates at an absolute TT Julian epoch.
    pub fn lteqec(epoch: f64, equatorial: EquatorialCoordinates) EclipticCoordinates {
        var dl: f64 = undefined;
        var db: f64 = undefined;
        c.eraLteqec(epoch, equatorial.right_ascension, equatorial.declination, &dl, &db);
        return .{ .longitude = dl, .latitude = db };
    }

    /// Convert ecliptic to ICRS equatorial coordinates at an absolute TT Julian epoch.
    pub fn lteceq(epoch: f64, position: EclipticCoordinates) EquatorialCoordinates {
        var dr: f64 = undefined;
        var dd: f64 = undefined;
        c.eraLteceq(epoch, position.longitude, position.latitude, &dr, &dd);
        return .{ .right_ascension = dr, .declination = dd };
    }

    /// Lieske precession matrix from J2000.0 to an absolute TT Julian epoch.
    pub fn ltp(epoch: f64) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraLtp(epoch, &matrix);
        return matrix;
    }

    /// Lieske precession-bias matrix from J2000.0 to an absolute TT Julian epoch.
    pub fn ltpb(epoch: f64) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraLtpb(epoch, &matrix);
        return matrix;
    }

    /// Ecliptic pole unit vector at an absolute TT Julian epoch.
    pub fn ltpecl(epoch: f64) Vec3 {
        var vector: Vec3 = undefined;
        c.eraLtpecl(epoch, &vector);
        return vector;
    }

    /// Equator pole unit vector at an absolute TT Julian epoch.
    pub fn ltpequ(epoch: f64) Vec3 {
        var vector: Vec3 = undefined;
        c.eraLtpequ(epoch, &vector);
        return vector;
    }
};

/// Analytical Earth, planetary and lunar ephemerides; upstream does not endorse them as IAU standards.
pub const ephemeris = struct {
    /// Heliocentric and barycentric Earth position/velocity for a TDB date.
    /// Always writes both outputs; `+1` warns when the date is outside 1900-2100.
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

    /// Planet ids 1-8 select Mercury through Neptune; `-1` zeroes `pv`, while `+1`/`+2` retain it.
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

    /// Geocentric Moon position and velocity; upstream returns no status.
    pub fn moon98(date: Date2) Pv {
        var pv: Pv = undefined;
        c.eraMoon98(date.part_a, date.part_b, pvPointer(&pv));
        return pv;
    }
};

/// The plain vector helpers the transformations are built from.
pub const vectors = struct {
    /// Split a vector into its modulus and unit direction; a zero vector yields zero for both.
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

    /// Deflect a unit source direction using body mass in solar masses and observer distance in au.
    /// `p`, `q` and `e` are unit vectors; the returned direction is not normalized.
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

    /// Scale position and velocity separately into a p-v vector.
    pub fn s2xpv(s1: f64, s2: f64, pv: Pv) Pv {
        var result: Pv = undefined;
        c.eraS2xpv(s1, s2, pvPointer(&pv), pvPointer(&result));
        return result;
    }

    /// Return position and velocity magnitudes separately; no relativistic speed check is performed.
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

    /// Return the position after `dt` days as a vector.
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

    /// Position angle of b relative to a, radians in `[-pi, pi]`; north is zero and east positive.
    /// Returns zero for coincident directions or a zero-length operand.
    pub fn pap(a: *const Vec3, b: *const Vec3) f64 {
        return c.eraPap(@constCast(a), @constCast(b));
    }

    /// Angular separation of two vectors, radians in `[0, pi]`; zero if either vector has zero length.
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

    /// Apply combined light deflection; observer offset is au and body state uses barycentric au/au-day.
    /// Returns the unchanged input direction and its deflected value; an empty body list leaves it unchanged.
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

    /// Deflect `p` using Sun-to-observer unit vector `e` and distance in au; output is not normalized.
    pub fn ldsun(
        p: *const Vec3,
        e: *const Vec3,
        observer_distance: f64,
    ) Vec3 {
        var deflected: Vec3 = undefined;
        c.eraLdsun(@constCast(p), @constCast(e), observer_distance, &deflected);
        return deflected;
    }

    /// Apply relativistic aberration to unit direction/velocity vectors; observer distance is Sun-observer au.
    /// `lorenz_reciprocal` is `sqrt(1 - |v|^2)`; the result is a unit vector.
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

    /// Return observer BCRS position/velocity (au, au/day) from site coordinates, polar motion and ERA.
    pub fn pvtob(longitude: f64, latitude: f64, height: f64, xp: f64, yp: f64, sp: f64, era: f64) Pv {
        var result: Pv = undefined;
        c.eraPvtob(longitude, latitude, height, xp, yp, sp, era, pvPointer(&result));
        return result;
    }

    /// Convert position/velocity to star motion; `-1`/`-2` leave `star` absent.
    /// Pass a private `Pv` copy because upstream overwrites its velocity input.
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

    /// Convert catalogue star motion to position/velocity; `+1`, `+2` and `+4` are warnings with `pv` present.
    /// For `+2`, upstream returns zero velocity rather than the input.
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

    /// Propagate star motion between two BCRS Julian Dates; `pvstar` errors map to `-1`.
    /// Negative status leaves `star` absent; warnings from `starpv` are preserved.
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

    /// Propagate star motion with parallax protection; upstream may raise parallax and report `+1`.
    /// The returned parallax may differ from the input.
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

    /// Propagate catalogue position by proper motion and parallax to a BCRS unit direction.
    /// `pm_years` is in Julian years; `observer_offset` is in au.
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
/// Fields and ranges returned by `eraA2af`; upstream returns no status.
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

/// Sign and sexagesimal fields returned by `eraA2tf`.
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

/// Tangent-plane coordinates `a` and `b`, radians; the frame is caller-defined.
pub const StandardCoordinates = struct {
    /// The `a` angle, radians.
    a: f64,
    /// The `b` angle, radians.
    b: f64,
};

/// `status` counts useful solutions (0-2), not success or warning.
/// Both solutions are absent only at zero; with count 1, `second` is present but unusable.
pub const TporsResult = struct {
    /// Solution count: 0 none, 1 first useful, 2 both useful.
    status: Status,
    /// Solution 1, absent only when the count is zero.
    first: ?StandardCoordinates,
    /// Solution 2; present with count 1 but not useful.
    second: ?StandardCoordinates,
};

/// Result of the Cartesian tangent-plane projection.
pub const TporvResult = struct {
    /// Count of useful solutions: 0, 1 or 2.
    status: Status,
    /// Solution 1, absent only when the count is zero.
    first: ?Vec3,
    /// Solution 2; present with count 1 but not useful.
    second: ?Vec3,
};

/// Inverse-projection coordinates are always present; positive status reports a near-singular divisor.
/// `+1`/`+2` clamp the divisor to ±1e-6; `+3` reports a point behind the great circle.
pub const TpxeResult = struct {
    /// `0` means normal; `+1`/`+2` mean the divisor was clamped, `+3` the point is behind the great circle.
    status: Status,
    /// The standard coordinates `xi` and `eta`, always present.
    coordinates: StandardCoordinates,
};

/// Rotation and FK5 spin vector from `eraFk5hip`.
pub const Fk5HipResult = struct {
    /// The B5-to-FK5-Hipparcos rotation matrix.
    rotation: Mat3,
    /// FK5 spin relative to Hipparcos, radians per Julian year; a rate, not an E-terms offset.
    spin: Vec3,
};

/// The two refraction constants `atmosphere.refco` computes.
pub const RefractionConstants = struct {
    /// Refraction constant A, radians.
    a: f64,
    /// Refraction constant B, radians.
    b: f64,
};

/// Angles from Cartesian conversion; upstream does not normalize `atan2` results.
/// A zero vector yields `theta == phi == 0`.
pub const SphericalAngles = struct {
    /// The longitude-like angle, radians, as `atan2` returned it.
    theta: f64,
    /// The latitude-like angle, radians, in `[-pi/2, pi/2]`.
    phi: f64,
};

/// A Cartesian point represented by two angles and a radius.
pub const CartesianSpherical = struct {
    /// See `SphericalAngles.theta`.
    theta: f64,
    /// See `SphericalAngles.phi`.
    phi: f64,
    /// The modulus of the point, in the caller's units.
    radius: f64,
};

/// Spherical position and velocity; rates are derivatives of radius and angles, not theta-weighted components.
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

/// Matrix, vector and position/velocity operations; rotation constructors start from identity.
/// Inputs are read-only and results are returned by value; these routines return no status.
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

    /// Return the complete identity matrix.
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

    /// Return the matrix product `a * b`.
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

    /// Return `transpose(matrix) * p`.
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

    /// Convert a matrix to its axis-angle rotation vector.
    /// Zero rotations yield zero; at pi, the branch may return either axis sign.
    pub fn toRotationVector(matrix: *const Mat3) Vec3 {
        var vector: Vec3 = undefined;
        c.eraRm2v(@constCast(matrix), &vector);
        return vector;
    }

    /// Convert an axis-angle rotation vector to a matrix; zero yields identity.
    pub fn fromRotationVector(vector: *const Vec3) Mat3 {
        var matrix: Mat3 = undefined;
        c.eraRv2m(@constCast(vector), &matrix);
        return matrix;
    }

    /// Copy a vector using upstream's `eraCp`.
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

/// Angle normalization and sexagesimal decomposition.
pub const angles = struct {
    /// `a` normalised into `[0, 2*pi)`, radians.
    pub fn anp(a: f64) f64 {
        return c.eraAnp(a);
    }

    /// `a` normalised into `[-pi, pi)`, radians.
    pub fn anpm(a: f64) f64 {
        return c.eraAnpm(a);
    }

    /// Convert radians to degrees, arcminutes, arcseconds and a fraction.
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

    /// Convert radians to hours, minutes, seconds and a fraction.
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
    /// Convert a Cartesian direction to spherical angles; zero vector yields both angles zero.
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

    /// Convert a position/velocity pair to spherical coordinates and rates.
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

    /// Convert angles to Cartesian coordinates; upstream does not normalize out-of-range `phi`.
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

    /// Convert spherical position and rates to a position/velocity pair.
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

/// Horizon conversions use north-zero, east-positive azimuth and return no status.
/// The azimuth output is normalized to `[0, 2*pi)`.
pub const horizon = struct {
    /// Convert azimuth/elevation to west-positive hour angle and declination at geodetic latitude.
    /// At the pole, a zero horizontal projection yields hour angle zero.
    pub fn azimuthElevationToHorizontal(azimuth: f64, elevation: f64, latitude: f64) ObservedSpherical {
        var hour_angle: f64 = undefined;
        var declination: f64 = undefined;
        c.eraAe2hd(azimuth, elevation, latitude, &hour_angle, &declination);
        return .{ .first = hour_angle, .second = declination };
    }

    /// Convert west-positive hour angle and declination to azimuth/elevation.
    /// Azimuth is `[0, 2*pi)` and is zero for an exactly polar line of sight.
    pub fn horizontalToAzimuthElevation(hour_angle: f64, declination: f64, latitude: f64) ObservedSpherical {
        var azimuth: f64 = undefined;
        var elevation: f64 = undefined;
        c.eraHd2ae(hour_angle, declination, latitude, &azimuth, &elevation);
        return .{ .first = azimuth, .second = elevation };
    }

    /// Parallax angle from hour angle, declination and latitude; returns zero for a zero numerator/denominator.
    pub fn horizontalToParallax(hour_angle: f64, declination: f64, latitude: f64) f64 {
        return c.eraHd2pa(hour_angle, declination, latitude);
    }
};

/// IAU 2006 ecliptic conversions use a TDB date and return no status.
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

/// A spherical coordinate pair without a declared reference frame.
pub const SphericalPair = struct {
    /// The first angle, radians. For `galactic` this is the longitude.
    longitude: f64,
    /// The second angle, radians. For `galactic` this is the latitude.
    latitude: f64,
};

/// Galactic/ICRS transforms use a fixed matrix and normalize their output angles.
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

/// Gnomonic projection about a reference point; coordinates are radians, not angles on the sky.
/// Result status counts solutions for forward calls and reports divisor clamping for inverse calls.
pub const gnomonic = struct {
    /// Return both tangent-plane solutions; status counts useful solutions.
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

    /// Return both tangent-plane solutions for a Cartesian direction; status counts useful solutions.
    pub fn fromVector(xi: f64, eta: f64, direction: *const Vec3) TporvResult {
        var v01: Vec3 = undefined;
        var v02: Vec3 = undefined;
        const status: Status = .{ .value = c.eraTporv(xi, eta, @constCast(direction), &v01, &v02) };
        if (status.value == 0) return .{ .status = status, .first = null, .second = null };
        return .{ .status = status, .first = v01, .second = v02 };
    }

    /// Convert tangent-plane coordinates to standard coordinates; upstream normalizes `a`.
    pub fn toStandardCoordinates(xi: f64, eta: f64, reference: StandardCoordinates) StandardCoordinates {
        var a: f64 = undefined;
        var b: f64 = undefined;
        c.eraTpsts(xi, eta, reference.a, reference.b, &a, &b);
        return .{ .a = a, .b = b };
    }

    /// Convert tangent-plane coordinates to a Cartesian direction.
    /// The output is not normalized; its reference-direction component retains the reference length.
    pub fn toVector(xi: f64, eta: f64, reference: *const Vec3) Vec3 {
        var vector: Vec3 = undefined;
        c.eraTpstv(xi, eta, @constCast(reference), &vector);
        return vector;
    }

    /// Project standard coordinates onto the tangent plane.
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

    /// Project a Cartesian direction onto the tangent plane.
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
    /// Compute refraction constants from pressure (mbar), temperature (°C), humidity (0-1) and wavelength (µm).
    /// Upstream performs no range checks and returns no status.
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

/// Star position and proper motion without parallax or radial velocity.
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

/// FK4, FK5 and Hipparcos transformations; no status is returned.
/// Angles and proper motions are radians and radians/Julian-year; parallax is arcseconds and velocity km/s.
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

    /// Convert FK4 B1950 position to FK5 J2000; `bepoch` is Besselian (a Julian epoch may also be used).
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

    /// Convert FK5 J2000 position/proper motion to FK4 B1950; `bepoch` is Besselian and parallax/radial velocity are omitted.
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

    /// Convert FK5 to Hipparcos, including parallax and radial velocity.
    /// Internal `starpv` warnings are discarded.
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

    /// Convert Hipparcos to FK5 J2000; the internal `starpv` status is discarded.
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

    /// Return the fixed Hipparcos-to-FK5 rotation and spin constants.
    pub fn hipparcosConstants() Fk5HipResult {
        var b5_to_fk5: Mat3 = undefined;
        var spin: Vec3 = undefined;
        c.eraFk5hip(&b5_to_fk5, &spin);
        return .{ .rotation = b5_to_fk5, .spin = spin };
    }

    /// Convert FK5 position at a TDB date to Hipparcos; only position is returned.
    pub fn fk5ToHipparcosAtDate(right_ascension: f64, declination: f64, date: Date2) EquatorialCoordinates {
        var rh: f64 = undefined;
        var dh: f64 = undefined;
        c.eraFk5hz(right_ascension, declination, date.part_a, date.part_b, &rh, &dh);
        return .{ .right_ascension = rh, .declination = dh };
    }

    /// Convert Hipparcos position at a TDB date to FK5 J2000; parallax is not transformed.
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

/// IERS 2003 fundamental arguments evaluated at TDB centuries since J2000, in radians.
/// Upstream does not normalize these results; use `angles.anp` when needed.
pub const fundamentalArgs = struct {
    /// `D`, the mean elongation of the Moon from the Sun (`src/fad03.c`).
    pub fn d(t: f64) f64 {
        return c.eraFad03(t);
    }

    /// `L'`, the mean longitude of Earth (`src/fae03.c`).
    pub fn earthLongitude(t: f64) f64 {
        return c.eraFae03(t);
    }

    /// `F`, mean longitude of the Moon minus its ascending node.
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

    /// `L'`, mean longitude of Saturn.
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
