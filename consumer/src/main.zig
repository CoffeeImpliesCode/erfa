//! External consumer of `erfa`; checks typed and raw APIs with published SOFA values.

const std = @import("std");
const erfa = @import("erfa");

const Mismatch = error{
    ConsumerMismatch,
    MissingOutput,
};

const ConfigurationError = error{NoProviderConfigured};

// Environment variable used when no provider path is passed on the command line.
const provider_variable = "ERFA_TEST_PROVIDER";

/// Gets the provider from `--provider <path>` or `ERFA_TEST_PROVIDER`.
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

/// Compares a numeric result with an expected value and tolerance.
fn report(label: []const u8, expected: f64, actual: f64, tolerance: f64) Mismatch!void {
    std.debug.print("{s: <34}{d}\n", .{ label, actual });
    if (!std.math.approxEqAbs(f64, expected, actual, tolerance)) {
        std.debug.print("expected: {d}\n", .{expected});
        return error.ConsumerMismatch;
    }
}

/// Checks a result status against SOFA's expected integer.
fn reportStatus(label: []const u8, expected: i32, status: erfa.Status) Mismatch!void {
    std.debug.print("{s: <34}{d}\n", .{ label, status.value });
    if (status.value != expected) {
        std.debug.print("expected status: {d}\n", .{expected});
        return error.ConsumerMismatch;
    }
}

pub fn main(init: std.process.Init) !void {
    // Load the provider before routed calls; linked builds do not enter this branch.
    if (comptime erfa.runtime_loaded) {
        try erfa.load(.{ .path = try providerRequest(init) });
        std.debug.print("consumer: loaded provider {s}\n", .{erfa.loadedSource().?.path});
    }
    std.debug.print("consumer: erfa {s}, SOFA base {s}\n", .{
        erfa.c.eraVersion(),
        erfa.c.eraSofaVersion(),
    });

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

    // Out-of-range input returns an error without a date.
    const rejected = erfa.calendar.jd2cal(.{ .part_a = -1e10, .part_b = 0.0 });
    try reportStatus("jd2cal out-of-range status", -1, rejected.status);
    if (rejected.date != null) return error.ConsumerMismatch;

    // A leap second is accepted; the next second returns the +2 warning.
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

    // TAI minus UTC was 32 s in 2003 and 37 s in 2020.
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

    // Geodetic coordinates round-trip through Cartesian conversion.
    const site = erfa.Geodetic{ .longitude = 3.1, .latitude = -0.5, .height = 2500.0 };
    const cartesian = erfa.geodetic.gd2gc(.wgs84, site).cartesian;
    try report("gd2gc x (m)", -5599000.5577049947, cartesian[0], 1e-7);
    const back = erfa.geodetic.gc2gd(.wgs84, &cartesian).geodetic;
    try report("gc2gd longitude", site.longitude, back.longitude, 1e-11);
    try report("gc2gd latitude", site.latitude, back.latitude, 1e-11);
    try report("gc2gd height (m)", site.height, back.height, 1e-6);

    const nutation = erfa.precession.pn06a(.{ .part_a = 2400000.5, .part_b = 53736.0 });
    try report("IAU2006A dpsi (rad)", -0.9630912025820308797e-5, nutation.dpsi, 1e-12);
    try report("IAU2006A epsa (rad)", 0.4090789763356509926, nutation.epsa, 1e-12);

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

    // The table is borrowed from the provider and needs no deinit.
    const table = erfa.leap.getLeapSeconds();
    const entries = table.entries orelse return error.MissingOutput;
    std.debug.print("{s: <34}{d}\n", .{ "leap table entries", entries.len });
    if (entries.len == 0) return error.MissingOutput;
    const last = entries[entries.len - 1];
    try report("TAI-UTC at last step (s)", 37.0, last.delat, 0.0);

    // Call raw translated declarations through `erfa.c`, beyond the typed facade.
    // Published SOFA values make these calls behavioral checks.
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

    // Check vector and matrix helpers with exact identities.
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

    // Horizon coordinates round-trip through azimuth and elevation.
    const horizontal = erfa.horizon.azimuthElevationToHorizontal(1.1, 0.4, 0.8);
    const altitude = erfa.horizon.horizontalToAzimuthElevation(horizontal.first, horizontal.second, 0.8);
    try report("horizon azimuth (rad)", 1.1, altitude.first, 1e-12);
    try report("horizon elevation (rad)", 0.4, altitude.second, 1e-12);

    // The tangent-plane projection and its inverse should agree.
    const reference = erfa.StandardCoordinates{ .a = 0.0, .b = 0.0 };
    const tangent_point = erfa.gnomonic.toStandardCoordinates(0.01, 0.02, reference);
    const back_to_tangent = erfa.gnomonic.fromStandardCoordinatesInverse(tangent_point, reference);
    try reportStatus("tpxes status", 0, back_to_tangent.status);
    try report("tpxes xi (rad)", 0.01, back_to_tangent.coordinates.a, 1e-6);
    try report("tpxes eta (rad)", 0.02, back_to_tangent.coordinates.b, 1e-6);

    std.debug.print("consumer: every checked value matched\n", .{});
}
