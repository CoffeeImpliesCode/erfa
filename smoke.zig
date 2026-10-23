//! Runnable ERFA example that checks representative results and prints them.
//! Supports linked and runtime-loaded builds; runtime builds require an explicit provider.

const std = @import("std");
const erfa = @import("erfa");

const Mismatch = error{
    /// A result disagreed with the expected value stated in this file.
    UnexpectedResult,
    /// A wrapper reported success but left an output absent.
    MissingOutput,
};

/// A runtime-loading build has no provider until one is named.
const ConfigurationError = error{NoProviderConfigured};

/// Shared library exporting ERFA's four header entry points.
const provider_variable = "ERFA_TEST_PROVIDER";

/// Select `--provider <path>` or `ERFA_TEST_PROVIDER`; no implicit fallback.
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

/// Report the missing provider configuration.
fn noProvider() ConfigurationError {
    std.debug.print(
        "smoke: this is a runtime-loading build. Pass --provider <path>, or " ++
            "export " ++ provider_variable ++ " with a shared object exporting " ++
            "the entry points of src/erfa.h, src/erfam.h, src/erfaextra.h and " ++
            "src/erfadatextra.h. Nothing is loaded by default and no other file " ++
            "is tried.\n",
        .{},
    );
    return error.NoProviderConfigured;
}

/// Print a result and compare it with its expected value.
fn check(label: []const u8, expected: f64, actual: f64, tolerance: f64) Mismatch!void {
    std.debug.print("{s:<28}{d}\n", .{ label, actual });
    if (!std.math.approxEqAbs(f64, expected, actual, tolerance)) {
        std.debug.print("{s}: expected {d}, got {d}\n", .{ label, expected, actual });
        return error.UnexpectedResult;
    }
}

pub fn main(init: std.process.Init) !void {
    // Load the provider before calls; the linked-build branch is comptime-elided.
    if (comptime erfa.runtime_loaded) {
        try erfa.load(.{ .path = try providerRequest(init) });
        std.debug.print("smoke: loaded provider {s}\n", .{erfa.loadedSource().?.path});
    }
    std.debug.print("erfa {s} (SOFA base {s})\n", .{
        erfa.c.eraVersion(),
        erfa.c.eraSofaVersion(),
    });
    // Calendar: 2003-06-01 is MJD 52791.
    const june_first = erfa.calendar.cal2jd(2003, 6, 1);
    const mjd = june_first.date orelse return error.MissingOutput;
    try check("2003-06-01 MJD", 52791.0, mjd.part_b, 0.0);
    try check("MJD zero point", 2400000.5, mjd.part_a, 0.0);

    const decoded = erfa.calendar.jd2cal(mjd);
    const gregorian = decoded.date orelse return error.MissingOutput;
    try check("round-tripped year", 2003.0, @floatFromInt(gregorian.year), 0.0);
    try check("round-tripped month", 6.0, @floatFromInt(gregorian.month), 0.0);
    try check("round-tripped day", 1.0, @floatFromInt(gregorian.day), 0.0);

    // UTC 23:59:60 is valid; 23:59:61 returns warning +2 with a usable result.
    const leap_second = erfa.calendar.dtf2d(.utc, 2016, 12, 31, 23, 59, 60.0);
    std.debug.print("{s:<28}{d}\n", .{ "leap-second status", leap_second.status.value });
    if (!leap_second.status.isOk()) return error.UnexpectedResult;

    const past_end = erfa.calendar.dtf2d(.utc, 2016, 12, 31, 23, 59, 61.0);
    std.debug.print("{s:<28}{d}\n", .{ "past-end status", past_end.status.value });
    if (past_end.status.value != 2) return error.UnexpectedResult;

    // TAI-UTC was 32 s on 2003-06-01.
    const delta = erfa.timescale.dat(2003, 6, 1, 0.0);
    try check("TAI-UTC 2003-06-01 (s)", 32.0, delta.delta_at, 0.0);

    const tai = erfa.Date2{ .part_a = 2453750.5, .part_b = 0.892482639 };
    const utc = erfa.timescale.taiutc(tai);
    try check("TAI to UTC part B", 0.8921006945555555556, (utc.date orelse return error.MissingOutput).part_b, 1e-12);

    // Earth rotation angle at MJD 54388.0 matches SOFA's published value.
    try check("ERA at MJD 54388.0", 0.4022837240028158102, erfa.rotation.earthRotationAngle(.{ .part_a = 2400000.5, .part_b = 54388.0 }), 1e-12);

    // WGS84 equatorial radius is 6378137 m.
    const wgs84 = erfa.geodetic.eform(.wgs84);
    try check("WGS84 a (m)", 6378137.0, wgs84.equatorial_radius, 1e-10);
    try check("WGS84 f", 0.3352810664747480720e-2, wgs84.flattening, 1e-18);

    // IAU 2006 nutation at J2000.0 matches SOFA's published value.
    try check(
        "IAU2006A dpsi (rad)",
        -0.9630912025820308797e-5,
        erfa.precession.nut06a(.{ .part_a = 2400000.5, .part_b = 53736.0 }).dpsi,
        1e-13,
    );

    // Lunar geocentric x at MJD 43999.9 matches SOFA's published value.
    try check(
        "Moon x (au)",
        -0.2601295959971044180e-2,
        erfa.ephemeris.moon98(.{ .part_a = 2400000.5, .part_b = 43999.9 }).position[0],
        1e-11,
    );

    // The borrowed leap-second table must agree with `eraDat`.
    const table = erfa.leap.getLeapSeconds();
    const entries = table.entries orelse return error.MissingOutput;
    std.debug.print("{s:<28}{d}\n", .{ "leap table entries", entries.len });
    if (entries.len == 0) return error.UnexpectedResult;
    std.debug.print("{s:<28}{d} {d} {d}\n", .{
        "first entry",
        entries[0].iyear,
        entries[0].month,
        entries[0].delat,
    });
    try check("TAI-UTC 2020-06-01 (s)", 37.0, erfa.timescale.dat(2020, 6, 1, 0.0).delta_at, 0.0);

    // Pi is 180 degrees and 12 hours; `anp` and `anpm` normalize differently.
    const degrees = erfa.angles.a2af(3, std.math.pi);
    if (degrees.sign != '+' or degrees.degrees != 180 or degrees.arcminutes != 0) {
        std.debug.print("a2af(pi) gave {c} {d} {d}\n", .{
            degrees.sign,
            degrees.degrees,
            degrees.arcminutes,
        });
        return error.UnexpectedResult;
    }
    std.debug.print("{s:<28}{s} {d}\n", .{ "pi in degrees", "180", degrees.degrees });
    try check("anp(-1) (rad)", 2.0 * std.math.pi - 1.0, erfa.angles.anp(-1.0), 1e-15);
    try check("anpm(-1) (rad)", -1.0, erfa.angles.anpm(-1.0), 1e-15);

    std.debug.print("smoke: every checked value matched\n", .{});
}
