//! Consumer of the `erfa` package: uses only what the package publishes.
//!
//! This is the same work `smoke.zig` does, written against the package the way
//! a dependent sees it: one module import, no build flags of its own, no
//! knowledge of the native sources. Every expected value is SOFA's own
//! published validation number, so a wrong answer fails the run instead of
//! printing silently, and the output is deterministic.
//!
//! It deliberately touches both routes. The typed wrappers show what a caller
//! gets by default; the two calls at the end go through `erfa.c`, the raw
//! translated header, to show that a dependent which needs a declaration the
//! wrappers do not name can still reach it without a second dependency.
//!
//! The same source builds against a linked package and against a
//! runtime-loaded one. `erfa.runtime_loaded` is a comptime constant, so the
//! difference is one branch and no duplicated program: in the runtime-loading
//! build the provider is named on the command line (`--provider <path>`) or in
//! `ERFA_TEST_PROVIDER` and loaded once, and the same answers follow.

const std = @import("std");
const erfa = @import("erfa");

const Mismatch = error{
    /// A result disagreed with the expected value stated in this file.
    ConsumerMismatch,
    /// A wrapper reported success but left an output absent.
    MissingOutput,
};

/// A runtime-loading build has no provider until one is named.
const ConfigurationError = error{NoProviderConfigured};

/// A shared object exporting the entry points of the four shipped headers,
/// named by the environment when the command line does not name one.
const provider_variable = "ERFA_TEST_PROVIDER";

/// The provider this run should load, from `--provider <path>` or from
/// `ERFA_TEST_PROVIDER`.
///
/// Both are explicit. Nothing here looks in a default location and falls back
/// to a linked copy: a runtime-loading build that was not told which file to
/// load says so and stops, rather than loading something else.
fn providerRequest(init: std.process.Init) ConfigurationError![]const u8 {
    const args = init.minimal.args.toSlice(init.arena.allocator()) catch
        return noProvider();
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        if (std.mem.eql(u8, args[index], "--provider")) {
            if (index + 1 >= args.len) return noProvider();
            return args[index + 1];
        }
    }
    return init.environ_map.get(provider_variable) orelse
        return noProvider();
}

/// Say which variable is missing. An error name on its own would send the next
/// person into the loader instead of to the command line.
fn noProvider() ConfigurationError {
    std.debug.print(
        "consumer: this is a runtime-loading build. Pass --provider <path>, or " ++
            "export " ++ provider_variable ++ " with a shared object exporting " ++
            "the entry points of src/erfa.h, src/erfam.h, src/erfaextra.h and " ++
            "src/erfadatextra.h. Nothing is loaded by default and no other file " ++
            "is tried.\n",
        .{},
    );
    return error.NoProviderConfigured;
}

/// Print `label` and `actual`, then fail unless it matches `expected`.
fn report(label: []const u8, expected: f64, actual: f64, tolerance: f64) Mismatch!void {
    std.debug.print("{s: <34}{d}\n", .{ label, actual });
    if (!std.math.approxEqAbs(f64, expected, actual, tolerance)) {
        std.debug.print("expected: {d}\n", .{expected});
        return error.ConsumerMismatch;
    }
}

/// Print a status, and fail unless it is exactly the integer the SOFA
/// validation case reports. A status is never reduced to a boolean here: the
/// number itself is the contract.
fn reportStatus(label: []const u8, expected: i32, status: erfa.Status) Mismatch!void {
    std.debug.print("{s: <34}{d}\n", .{ label, status.value });
    if (status.value != expected) {
        std.debug.print("expected status: {d}\n", .{expected});
        return error.ConsumerMismatch;
    }
}

pub fn main(init: std.process.Init) !void {
    // In a runtime-loading build nothing below is reachable until the table
    // exists, so the provider is loaded first and reported. The branch is
    // comptime, so a linked build never mentions the loader at all.
    if (comptime erfa.runtime_loaded) {
        try erfa.load(.{ .path = try providerRequest(init) });
        std.debug.print("consumer: loaded provider {s}\n", .{erfa.loadedSource().?.path});
    }
    std.debug.print("consumer: erfa {s}, SOFA base {s}\n", .{
        erfa.c.eraVersion(),
        erfa.c.eraSofaVersion(),
    });

    // Calendars. 2003 June 1 is MJD 52791 and the MJD zero point is fixed.
    const converted = erfa.calendar.cal2jd(2003, 6, 1);
    try reportStatus("cal2jd status", 0, converted.status);
    const mjd = converted.date orelse return error.MissingOutput;
    try report("cal2jd MJD zero point", 2400000.5, mjd.part_a, 0.0);
    try report("cal2jd MJD", 52791.0, mjd.part_b, 0.0);

    const decoded = erfa.calendar.jd2cal(mjd);
    try reportStatus("jd2cal status", 0, decoded.status);
    const gregorian = decoded.date orelse return error.MissingOutput;
    try report("jd2cal year", 2003.0, @floatFromInt(gregorian.year), 0.0);
    try report("jd2cal month", 6.0, @floatFromInt(gregorian.month), 0.0);
    try report("jd2cal day", 1.0, @floatFromInt(gregorian.day), 0.0);

    // A rejected date is an error and writes nothing, which the result type
    // makes visible instead of leaving a stale value behind.
    const rejected = erfa.calendar.jd2cal(.{ .part_a = -1e10, .part_b = 0.0 });
    try reportStatus("jd2cal out-of-range status", -1, rejected.status);
    if (rejected.date != null) return error.ConsumerMismatch;

    // A leap second is accepted, and the second past it is the +2 warning with
    // a result that is still usable.
    const leap_second = erfa.calendar.dtf2d(.utc, 2016, 12, 31, 23, 59, 60.0);
    try reportStatus("dtf2d leap second status", 0, leap_second.status);
    const past_end = erfa.calendar.dtf2d(.utc, 2016, 12, 31, 23, 59, 61.0);
    try reportStatus("dtf2d past-end status", 2, past_end.status);
    const past_end_date = past_end.date orelse return error.MissingOutput;
    try report("dtf2d following midnight fraction", 1.0, past_end_date.part_b, 0.0);

    const formatted = erfa.calendar.d2dtf(.utc, 5, .{ .part_a = 2400000.5, .part_b = 49533.99999 });
    try reportStatus("d2dtf status", 0, formatted.status);
    const utc_time = formatted.time orelse return error.MissingOutput;
    try report("d2dtf second of the minute", 60.0, @floatFromInt(utc_time.second), 0.0);

    // Timescales. TAI minus UTC was 32 s on 2003 June 1 and 37 s in 2020.
    try report("TAI-UTC 2003-06-01 (s)", 32.0, erfa.timescale.dat(2003, 6, 1, 0.0).delta_at, 0.0);
    try report("TAI-UTC 2020-06-01 (s)", 37.0, erfa.timescale.dat(2020, 6, 1, 0.0).delta_at, 0.0);

    const tai = erfa.Date2{ .part_a = 2453750.5, .part_b = 0.892482639 };
    const tai_utc = erfa.timescale.taiutc(tai);
    try reportStatus("taiutc status", 0, tai_utc.status);
    try report(
        "taiutc part B",
        0.8921006945555555556,
        (tai_utc.date orelse return error.MissingOutput).part_b,
        1e-12,
    );

    // Earth rotation.
    try report(
        "ERA at MJD 54388.0 (rad)",
        0.4022837240028158102,
        erfa.rotation.earthRotationAngle(.{ .part_a = 2400000.5, .part_b = 54388.0 }),
        1e-12,
    );
    try report(
        "GMST at J2000.0 (rad)",
        1.754174972210740592,
        erfa.rotation.gmst00(
            .{ .part_a = 2400000.5, .part_b = 53736.0 },
            .{ .part_a = 2400000.5, .part_b = 53736.0 },
        ),
        1e-12,
    );

    // Geodetic conversion. A geodetic position round-trips through the
    // Cartesian vector to well within the accuracy of the transformation.
    const site = erfa.Geodetic{ .longitude = 3.1, .latitude = -0.5, .height = 2500.0 };
    const cartesian = erfa.geodetic.gd2gc(.wgs84, site).cartesian;
    try report("gd2gc x (m)", -5599000.5577049947, cartesian[0], 1e-7);
    const back = erfa.geodetic.gc2gd(.wgs84, &cartesian).geodetic;
    try report("gc2gd longitude", site.longitude, back.longitude, 1e-11);
    try report("gc2gd latitude", site.latitude, back.latitude, 1e-11);
    try report("gc2gd height (m)", site.height, back.height, 1e-6);

    // Precession and nutation.
    const nutation = erfa.precession.pn06a(.{ .part_a = 2400000.5, .part_b = 53736.0 });
    try report("IAU2006A dpsi (rad)", -0.9630912025820308797e-5, nutation.dpsi, 1e-12);
    try report("IAU2006A epsa (rad)", 0.4090789763356509926, nutation.epsa, 1e-12);

    // Ephemerides.
    try report(
        "Earth heliocentric x (au)",
        -0.7757238809297706813,
        erfa.ephemeris.epv00(.{ .part_a = 2400000.5, .part_b = 53411.52501161 }).heliocentric.position[0],
        1e-14,
    );
    try report(
        "Moon x (au)",
        -0.2601295959971044180e-2,
        erfa.ephemeris.moon98(.{ .part_a = 2400000.5, .part_b = 43999.9 }).position[0],
        1e-11,
    );

    // The leap-second table is borrowed, not copied. It is read, used to
    // explain the last TAI-UTC step, and left alone: upstream owns the
    // storage, so there is nothing to free and no `deinit` to call.
    const table = erfa.leap.getLeapSeconds();
    const entries = table.entries orelse return error.MissingOutput;
    std.debug.print("{s: <34}{d}\n", .{ "leap table entries", entries.len });
    if (entries.len == 0) return error.MissingOutput;
    const last = entries[entries.len - 1];
    try report("TAI-UTC at last step (s)", 37.0, last.delat, 0.0);

    // Raw C route, for declarations the typed layer does not name. They are
    // reached through the module the facade re-exports, with no second
    // dependency and without this program declaring libc itself.
    //
    // `eraAnp` normalises an angle into [0, 2pi) and `eraAnpm` into [-pi, pi],
    // so the same input comes back through the two as two different angles.
    // Checking both makes reaching the raw route an assertion about behaviour
    // rather than a reference that proves nothing.
    try report(
        "raw eraAnp(-1.0) (rad)",
        2.0 * std.math.pi - 1.0,
        erfa.c.eraAnp(-1.0),
        1e-15,
    );
    try report(
        "raw eraAnpm(-1.0) (rad)",
        -1.0,
        erfa.c.eraAnpm(-1.0),
        1e-15,
    );

    // The vector and matrix algebra the transformations are built from, with
    // the two exact known answers this package can state without a reference:
    // pi radians is 180 degrees, and the identity matrix is its own inverse.
    const degrees = erfa.angles.a2af(3, std.math.pi);
    std.debug.print("{s: <34}{d} {d} {d}\n", .{
        "a2af(pi) degrees/min/sec",
        degrees.degrees,
        degrees.arcminutes,
        degrees.arcseconds,
    });
    if (degrees.sign != '+' or degrees.degrees != 180 or degrees.arcminutes != 0) {
        std.debug.print("a2af(pi) did not give 180 degrees\n", .{});
        return error.ConsumerMismatch;
    }

    const identity = erfa.matrices.identity();
    const squaring = erfa.matrices.multiply(&identity, &identity);
    for (0..3) |row| {
        for (0..3) |column| {
            try report(
                "identity squared",
                if (row == column) 1.0 else 0.0,
                squaring[row][column],
                0.0,
            );
        }
    }

    // A line of sight at the horizon converts to azimuth and elevation and
    // back, and the two agree because upstream builds each from the other.
    const horizontal = erfa.horizon.azimuthElevationToHorizontal(1.1, 0.4, 0.8);
    const altitude = erfa.horizon.horizontalToAzimuthElevation(horizontal.first, horizontal.second, 0.8);
    try report("horizon azimuth (rad)", 1.1, altitude.first, 1e-12);
    try report("horizon elevation (rad)", 0.4, altitude.second, 1e-12);

    // The tangent plane projection inverts, which is the property the
    // projection is defined by and the reason `tpsts` and `tpxes` are each
    // other's inverse.
    const reference = erfa.StandardCoordinates{ .a = 0.0, .b = 0.0 };
    const tangent_point = erfa.gnomonic.toStandardCoordinates(0.01, 0.02, reference);
    const back_to_tangent = erfa.gnomonic.fromStandardCoordinatesInverse(tangent_point, reference);
    try reportStatus("tpxes status", 0, back_to_tangent.status);
    try report("tpxes xi (rad)", 0.01, back_to_tangent.coordinates.a, 1e-6);
    try report("tpxes eta (rad)", 0.02, back_to_tangent.coordinates.b, 1e-6);

    std.debug.print("consumer: every checked value matched\n", .{});
}
