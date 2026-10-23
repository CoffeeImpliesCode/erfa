//! Tests for the ERFA Zig facade against SOFA reference values and behavior.
//! Covers upstream status/output contracts, leap-table ownership and facade-specific edges.
//! Known answers follow upstream's `src/t_erfa_c.c` unless stated otherwise.

const std = @import("std");
const erfa = @import("erfa");
const testing = std.testing;

/// Shared library exporting ERFA's four headers' entry points.
const provider_variable = "ERFA_TEST_PROVIDER";

/// Ensure a runtime provider is loaded before each test; linked builds need none.
/// Repeats are idempotent, and filtered tests do not fall back to linked code.
fn nativeReady() void {
    if (comptime !erfa.runtime_loaded) return;
    if (erfa.loadedSource() != null) return;

    var buffer: [4096]u8 = undefined;
    const value = testing.environ.getAlloc(testing.allocator, provider_variable) catch
        missingProvider();
    defer testing.allocator.free(value);
    if (value.len == 0 or value.len > buffer.len) missingProvider();
    @memcpy(buffer[0..value.len], value);
    erfa.load(.{ .path = buffer[0..value.len] }) catch |err| {
        std.debug.print(
            "tests.zig: loading " ++ provider_variable ++ " = \"{s}\" failed: {t}\n",
            .{ buffer[0..value.len], err },
        );
        @panic("tests.zig: the provider named by " ++ provider_variable ++
            " did not load; nothing below this line ran");
    };
}

fn missingProvider() noreturn {
    @panic(
        "tests.zig: this is a runtime-loading build and " ++ provider_variable ++
            " is not set. Point it at a shared object exporting the entry " ++
            "points of src/erfa.h, src/erfam.h, src/erfaextra.h and " ++
            "src/erfadatextra.h, for example the one `zig build " ++
            "-Dlinkage=dynamic -Doptimize=Debug` installs, and export it for " ++
            "the whole `zig build` invocation: the build cannot inject a path " ++
            "into a run step's environment.",
    );
}

/// Compare with a SOFA validation value at upstream's tolerance.
fn expectNear(expected: f64, actual: f64, tolerance: f64) !void {
    try testing.expectApproxEqAbs(expected, actual, tolerance);
}

test "calendar.cal2jd: SOFA value and the MJD split" {
    nativeReady();

    const result = erfa.calendar.cal2jd(2003, 6, 1);
    try testing.expect(result.status.isOk());
    const date = result.date orelse return error.MissingOutput;
    try expectNear(2400000.5, date.part_a, 0.0);
    try expectNear(52791.0, date.part_b, 0.0);
    try expectNear(2452791.5, date.sum(), 1e-12);
}

test "calendar.cal2jd: bad year and bad month compute nothing" {
    nativeReady();

    // The algorithm accepts dates from -4800 March 1 onward.
    const year = erfa.calendar.cal2jd(-4800, 1, 1);
    try testing.expectEqual(@as(i32, -1), year.status.value);
    try testing.expect(year.date == null);

    const month = erfa.calendar.cal2jd(2003, 13, 1);
    try testing.expectEqual(@as(i32, -2), month.status.value);
    try testing.expect(month.date == null);
}

test "calendar.cal2jd: a bad day is an error that still computes the date" {
    nativeReady();

    // An invalid day reports `-3` but still returns its computed Julian Date.
    const result = erfa.calendar.cal2jd(2003, 2, 29);
    try testing.expectEqual(@as(i32, -3), result.status.value);
    const date = result.date orelse return error.MissingOutput;
    try expectNear(2400000.5, date.part_a, 0.0);
    try expectNear(52699.0, date.part_b, 0.0); // 2003-03-01

    // Leap years accept February 29.
    const leap = erfa.calendar.cal2jd(2004, 2, 29);
    try testing.expect(leap.status.isOk());
    try expectNear(53064.0, (leap.date orelse return error.MissingOutput).part_b, 0.0);
}

test "calendar.jd2cal: SOFA value, and the split does not matter" {
    nativeReady();

    // Upstream's MJD-split case.
    const mjd = erfa.calendar.jd2cal(.{ .part_a = 2400000.5, .part_b = 50123.9999 });
    try testing.expect(mjd.status.isOk());
    const first = mjd.date orelse return error.MissingOutput;
    try testing.expectEqual(@as(i32, 1996), first.year);
    try testing.expectEqual(@as(i32, 2), first.month);
    try testing.expectEqual(@as(i32, 10), first.day);
    try expectNear(0.9999, first.fraction, 1e-7);

    // Exactly representable fractions isolate the split invariant.
    const splits = [_]erfa.Date2{
        .{ .part_a = 2400000.5, .part_b = 50123.75 },
        .{ .part_a = 2450124.25, .part_b = 0.0 },
        .{ .part_a = 2451545.0, .part_b = -1420.75 },
    };
    for (splits) |split| {
        const got = erfa.calendar.jd2cal(split).date orelse return error.MissingOutput;
        try testing.expectEqual(first.year, got.year);
        try testing.expectEqual(first.month, got.month);
        try testing.expectEqual(first.day, got.day);
        try expectNear(0.75, got.fraction, 0.0);
    }
}

test "calendar.jd2cal: the accepted range is closed at both ends" {
    nativeReady();

    // Dates outside `[-68569.5, 1e9]` leave the output absent.
    const too_early = erfa.calendar.jd2cal(.{ .part_a = -68570.0, .part_b = 0.0 });
    try testing.expectEqual(@as(i32, -1), too_early.status.value);
    try testing.expect(too_early.date == null);

    const too_late = erfa.calendar.jd2cal(.{ .part_a = 1e9 + 1.0, .part_b = 0.0 });
    try testing.expectEqual(@as(i32, -1), too_late.status.value);

    // The earliest valid date is accepted.
    const earliest = erfa.calendar.jd2cal(.{ .part_a = -68569.5, .part_b = 0.0 });
    try testing.expect(earliest.status.isOk());
    const date = earliest.date orelse return error.MissingOutput;
    try testing.expectEqual(@as(i32, -4900), date.year);
    try testing.expectEqual(@as(i32, 3), date.month);
    try testing.expectEqual(@as(i32, 1), date.day);
}

test "calendar.jdcalf: SOFA value, and a bad ndp is a warning not an error" {
    nativeReady();

    const good = erfa.calendar.jdcalf(4, .{ .part_a = 2400000.5, .part_b = 50123.9999 });
    try testing.expect(good.status.isOk());
    const rounded = good.date orelse return error.MissingOutput;
    try testing.expectEqual(@as(i32, 1996), rounded.year);
    try testing.expectEqual(@as(i32, 2), rounded.month);
    try testing.expectEqual(@as(i32, 10), rounded.day);
    try testing.expectEqual(@as(i32, 9999), rounded.fraction);

    // Out-of-range `ndp` becomes zero with warning `+1`, but retains the result.
    const warned = erfa.calendar.jdcalf(11, .{ .part_a = 2400000.5, .part_b = 50123.9999 });
    try testing.expect(warned.status.isWarning());
    try testing.expectEqual(@as(i32, 1), warned.status.value);
    const zero_places = warned.date orelse return error.MissingOutput;
    try testing.expectEqual(@as(i32, 1996), zero_places.year);
    try testing.expectEqual(@as(i32, 0), zero_places.fraction);
}

test "calendar.dtf2d: SOFA leap-second value and the unnormalised fraction" {
    nativeReady();

    // On a leap-second day, the second part uses 86401 seconds.
    const result = erfa.calendar.dtf2d(.utc, 1994, 6, 30, 23, 59, 60.13599);
    try testing.expect(result.status.isOk());
    const date = result.date orelse return error.MissingOutput;
    try expectNear(2449534.49999, date.sum(), 1e-6);

    // Time past day end returns `+2` and can leave `part_b` above 1.
    const past = erfa.calendar.dtf2d(.utc, 1994, 6, 29, 23, 59, 60.5);
    try testing.expectEqual(@as(i32, 2), past.status.value);
    const past_date = past.date orelse return error.MissingOutput;
    if (past_date.part_b <= 1.0) return error.FractionWasNormalised;
}

test "calendar.dtf2d: the second-limit is 60 on an ordinary day and 61 on a leap day" {
    nativeReady();

    // On a leap-second day, second 60 is valid and 61 warns with `+2`.
    const accepted = erfa.calendar.dtf2d(.utc, 2016, 12, 31, 23, 59, 60.0);
    try testing.expect(accepted.status.isOk());

    const warned = erfa.calendar.dtf2d(.utc, 2016, 12, 31, 23, 59, 61.0);
    try testing.expectEqual(@as(i32, 2), warned.status.value);

    // On an ordinary day, second 60 is past the limit.
    const ordinary = erfa.calendar.dtf2d(.utc, 2016, 12, 30, 23, 59, 60.0);
    try testing.expectEqual(@as(i32, 2), ordinary.status.value);
}

test "calendar.dtf2d: every negative status writes nothing" {
    nativeReady();

    const cases = [_]struct { y: i32, m: i32, d: i32, hh: i32, mm: i32, ss: f64, want: i32 }{
        .{ .y = -4800, .m = 1, .d = 1, .hh = 0, .mm = 0, .ss = 0.0, .want = -1 },
        .{ .y = 2003, .m = 13, .d = 1, .hh = 0, .mm = 0, .ss = 0.0, .want = -2 },
        .{ .y = 2003, .m = 2, .d = 29, .hh = 0, .mm = 0, .ss = 0.0, .want = -3 },
        .{ .y = 2003, .m = 6, .d = 1, .hh = 24, .mm = 0, .ss = 0.0, .want = -4 },
        .{ .y = 2003, .m = 6, .d = 1, .hh = 0, .mm = 60, .ss = 0.0, .want = -5 },
        .{ .y = 2003, .m = 6, .d = 1, .hh = 0, .mm = 0, .ss = -1.0, .want = -6 },
    };
    for (cases) |case| {
        const result = erfa.calendar.dtf2d(.utc, case.y, case.m, case.d, case.hh, case.mm, case.ss);
        try testing.expectEqual(case.want, result.status.value);
        try testing.expect(result.date == null);
    }
}

test "calendar.d2dtf: SOFA value, and a UTC leap second decodes to second 60" {
    nativeReady();

    const result = erfa.calendar.d2dtf(.utc, 5, .{ .part_a = 2400000.5, .part_b = 49533.99999 });
    try testing.expect(result.status.isOk());
    const date = result.date orelse return error.MissingOutput;
    try testing.expectEqual(@as(i32, 1994), date.year);
    try testing.expectEqual(@as(i32, 6), date.month);
    try testing.expectEqual(@as(i32, 30), date.day);
    const time = result.time orelse return error.MissingOutput;
    try testing.expectEqual(@as(i32, 23), time.hour);
    try testing.expectEqual(@as(i32, 59), time.minute);
    try testing.expectEqual(@as(i32, 60), time.second);
    try testing.expectEqual(@as(i32, 13599), time.fraction);
}

test "calendar.d2dtf: an unacceptable date leaves both fields absent" {
    nativeReady();

    const result = erfa.calendar.d2dtf(.utc, 5, .{ .part_a = -1e10, .part_b = 0.0 });
    try testing.expectEqual(@as(i32, -1), result.status.value);
    try testing.expect(result.date == null);
    try testing.expect(result.time == null);
}

test "calendar.d2tf: SOFA value, sign and fields" {
    nativeReady();

    const result = erfa.calendar.d2tf(4, -0.987654321);
    try testing.expectEqual(@as(u8, '-'), result.sign);
    try testing.expectEqual(@as(i32, 23), result.hour);
    try testing.expectEqual(@as(i32, 42), result.minute);
    try testing.expectEqual(@as(i32, 13), result.second);
    try testing.expectEqual(@as(i32, 3333), result.fraction);
}

test "calendar.tf2d, tf2a and af2a: SOFA values and the warning ladder" {
    nativeReady();

    const tf2d = erfa.calendar.tf2d(' ', 23, 55, 10.9);
    try testing.expect(tf2d.status.isOk());
    try expectNear(0.9966539351851851852, tf2d.days, 1e-12);

    const tf2a = erfa.calendar.tf2a('+', 4, 58, 20.2);
    try testing.expect(tf2a.status.isOk());
    try expectNear(1.301739278189537429, tf2a.radians, 1e-12);

    const af2a = erfa.calendar.af2a('-', 45, 13, 27.2);
    try testing.expect(af2a.status.isOk());
    try expectNear(-0.7893115794313644842, af2a.radians, 1e-12);

    // Invalid time fields warn, but the absolute-value result is still computed.
    const bad_hour = erfa.calendar.tf2d('+', 24, 0, 0.0);
    try testing.expectEqual(@as(i32, 1), bad_hour.status.value);
    try expectNear(1.0, bad_hour.days, 1e-15);

    const bad_minute = erfa.calendar.af2a('+', 0, 60, 0.0);
    try testing.expectEqual(@as(i32, 2), bad_minute.status.value);

    const bad_second = erfa.calendar.af2a('+', 0, 0, 60.0);
    try testing.expectEqual(@as(i32, 3), bad_second.status.value);

    // Only the first invalid field is reported.
    const two_bad = erfa.calendar.tf2d('+', 99, 99, 99.0);
    try testing.expectEqual(@as(i32, 1), two_bad.status.value);
}

test "calendar epoch conversions: SOFA values" {
    nativeReady();

    try expectNear(1982.418424159278580, erfa.calendar.epb(.{ .part_a = 2415019.8135, .part_b = 30103.18648 }), 1e-12);

    const epb_date = erfa.calendar.epb2jd(1957.3);
    try expectNear(2400000.5, epb_date.part_a, 1e-9);
    try expectNear(35948.1915101513, epb_date.part_b, 1e-9);

    try expectNear(1979.760438056125941, erfa.calendar.epj(.{ .part_a = 2451545.0, .part_b = -7392.5 }), 1e-12);

    const epj_date = erfa.calendar.epj2jd(1996.8);
    try expectNear(2400000.5, epj_date.part_a, 1e-9);
    try expectNear(50375.7, epj_date.part_b, 1e-9);
}

test "timescale.dat: SOFA values across three leap seconds" {
    nativeReady();

    const first = erfa.timescale.dat(2003, 6, 1, 0.0);
    try testing.expect(first.status.isOk());
    try expectNear(32.0, first.delta_at, 0.0);

    const second = erfa.timescale.dat(2008, 1, 17, 0.0);
    try testing.expect(second.status.isOk());
    try expectNear(33.0, second.delta_at, 0.0);

    const third = erfa.timescale.dat(2017, 9, 1, 0.0);
    try testing.expect(third.status.isOk());
    try expectNear(37.0, third.delta_at, 0.0);
}

test "timescale.dat: the boundary either side of the 2016-12-31 leap second" {
    nativeReady();

    // The leap-second step takes effect on 1 January 2017.
    const before = erfa.timescale.dat(2016, 12, 31, 0.0);
    try testing.expect(before.status.isOk());
    try expectNear(36.0, before.delta_at, 0.0);

    const after = erfa.timescale.dat(2017, 1, 1, 0.0);
    try testing.expect(after.status.isOk());
    try expectNear(37.0, after.delta_at, 0.0);

    // The 2015-07-01 step follows the same boundary rule.
    try expectNear(35.0, erfa.timescale.dat(2015, 6, 30, 0.0).delta_at, 0.0);
    try expectNear(36.0, erfa.timescale.dat(2015, 7, 1, 0.0).delta_at, 0.0);
}

test "timescale.dat: a pre-UTC year warns and returns nothing" {
    nativeReady();

    // Before UTC began, warning `+1` carries a zero delta.
    const result = erfa.timescale.dat(1959, 12, 31, 0.0);
    try testing.expect(result.status.isWarning());
    try testing.expectEqual(@as(i32, 1), result.status.value);
    try expectNear(0.0, result.delta_at, 0.0);
}

test "timescale.dat: a far-future year warns and still computes" {
    nativeReady();

    // This pin's IYV is 2023; dates after 2028 warn but retain the computed offset.
    const result = erfa.timescale.dat(2029, 6, 1, 0.0);
    try testing.expect(result.status.isWarning());
    try testing.expectEqual(@as(i32, 1), result.status.value);
    try expectNear(37.0, result.delta_at, 0.0);

    // The preceding year is inside the trusted window.
    try testing.expect(erfa.timescale.dat(2028, 6, 1, 0.0).status.isOk());
}

test "timescale.dat: a bad fraction of the day is an error with a zero result" {
    nativeReady();

    const result = erfa.timescale.dat(2003, 6, 1, 1.5);
    try testing.expectEqual(@as(i32, -4), result.status.value);
    try expectNear(0.0, result.delta_at, 0.0);

    // When several inputs are invalid, the first error wins.
    const month_bad = erfa.timescale.dat(2003, 13, 32, 0.0);
    try testing.expectEqual(@as(i32, -2), month_bad.status.value);
}

test "timescale conversions: SOFA values" {
    nativeReady();

    const tai = erfa.Date2{ .part_a = 2453750.5, .part_b = 0.892482639 };

    const taiutc = erfa.timescale.taiutc(tai);
    try testing.expect(taiutc.status.isOk());
    const utc = taiutc.date orelse return error.MissingOutput;
    try expectNear(2453750.5, utc.part_a, 1e-6);
    try expectNear(0.8921006945555555556, utc.part_b, 1e-12);

    const utctai = erfa.timescale.utctai(.{ .part_a = 2453750.5, .part_b = 0.892100694 });
    try testing.expect(utctai.status.isOk());
    const back = utctai.date orelse return error.MissingOutput;
    try expectNear(2453750.5, back.part_a, 1e-6);
    try expectNear(0.8924826384444444444, back.part_b, 1e-12);

    const ut1 = erfa.Date2{ .part_a = 2453750.5, .part_b = 0.892104561 };
    const ut1utc = erfa.timescale.ut1utc(ut1, 0.3341);
    try testing.expect(ut1utc.status.isOk());
    const utc_from_ut1 = ut1utc.date orelse return error.MissingOutput;
    try expectNear(2453750.5, utc_from_ut1.part_a, 1e-6);
    try expectNear(0.8921006941018518519, utc_from_ut1.part_b, 1e-12);

    // Compare the upstream-published UTC input, not the result of the preceding conversion.
    const utcut1 = erfa.timescale.utcut1(.{ .part_a = 2453750.5, .part_b = 0.892100694 }, 0.3341);
    try testing.expect(utcut1.status.isOk());
    const ut1_direct = utcut1.date orelse return error.MissingOutput;
    try expectNear(2453750.5, ut1_direct.part_a, 1e-6);
    try expectNear(0.8921045608981481481, ut1_direct.part_b, 1e-12);

    const ut1tai = erfa.timescale.ut1tai(ut1, -32.6659);
    try expectNear(0.8924826385462962963, (ut1tai.date orelse return error.MissingOutput).part_b, 1e-12);

    const taiut1 = erfa.timescale.taiut1(tai, -32.6659);
    try expectNear(0.8921045614537037037, (taiut1.date orelse return error.MissingOutput).part_b, 1e-12);

    const ut1tt = erfa.timescale.ut1tt(ut1, 64.8499);
    try expectNear(0.8928551385462962963, (ut1tt.date orelse return error.MissingOutput).part_b, 1e-12);

    const ttut1 = erfa.timescale.ttut1(.{ .part_a = 2453750.5, .part_b = 0.892855139 }, 64.8499);
    try expectNear(0.8921045614537037037, (ttut1.date orelse return error.MissingOutput).part_b, 1e-12);

    const taitt = erfa.timescale.taitt(tai);
    try expectNear(0.892855139, (taitt.date orelse return error.MissingOutput).part_b, 1e-12);

    const tttai = erfa.timescale.tttai(.{ .part_a = 2453750.5, .part_b = 0.892482639 });
    try expectNear(0.892110139, (tttai.date orelse return error.MissingOutput).part_b, 1e-12);

    const tcgtt = erfa.timescale.tcgtt(.{ .part_a = 2453750.5, .part_b = 0.892862531 });
    try expectNear(0.8928551387488816828, (tcgtt.date orelse return error.MissingOutput).part_b, 1e-12);

    const tttcg = erfa.timescale.tttcg(.{ .part_a = 2453750.5, .part_b = 0.892482639 });
    try expectNear(0.8924900312508587113, (tttcg.date orelse return error.MissingOutput).part_b, 1e-12);

    const tcbtdb = erfa.timescale.tcbtdb(.{ .part_a = 2453750.5, .part_b = 0.893019599 });
    try expectNear(0.8928551362746343397, (tcbtdb.date orelse return error.MissingOutput).part_b, 1e-12);

    const tdbtcb = erfa.timescale.tdbtcb(.{ .part_a = 2453750.5, .part_b = 0.892855137 });
    try expectNear(0.8930195997253656716, (tdbtcb.date orelse return error.MissingOutput).part_b, 1e-12);

    const tdbtt = erfa.timescale.tdbtt(.{ .part_a = 2453750.5, .part_b = 0.892855137 }, -0.000201);
    try expectNear(0.8928551393263888889, (tdbtt.date orelse return error.MissingOutput).part_b, 1e-12);

    const tttdb = erfa.timescale.tttdb(.{ .part_a = 2453750.5, .part_b = 0.892855139 }, -0.000201);
    try expectNear(0.8928551366736111111, (tttdb.date orelse return error.MissingOutput).part_b, 1e-12);
}

test "timescale conversions: an unacceptable date leaves the output absent" {
    nativeReady();

    const result = erfa.timescale.utctai(.{ .part_a = -1e10, .part_b = 0.0 });
    try testing.expectEqual(@as(i32, -1), result.status.value);
    try testing.expect(result.date == null);
}

test "leap seconds: the built-in table is what upstream publishes" {
    nativeReady();

    const table = erfa.leap.getLeapSeconds();
    try testing.expect(table.status.value > 0);
    const entries = table.entries orelse return error.MissingOutput;
    try testing.expectEqual(@as(usize, 42), entries.len);

    // The table starts on 1960-01-01 with TAI-UTC = 1.4178180 s.
    try testing.expectEqual(@as(c_int, 1960), entries[0].iyear);
    try testing.expectEqual(@as(c_int, 1), entries[0].month);
    try expectNear(1.4178180, entries[0].delat, 0.0);

    // The table ends with the 2016-12-31 leap second.
    const last = entries[entries.len - 1];
    try testing.expectEqual(@as(c_int, 2017), last.iyear);
    try testing.expectEqual(@as(c_int, 1), last.month);
    try expectNear(37.0, last.delat, 0.0);
}

test "leap seconds: the setter retains a caller table for this thread" {
    nativeReady();

    // `eraDat` applies drift to the first 14 rows; preserve that prefix.
    const builtin = erfa.leap.getLeapSeconds().entries orelse return error.MissingOutput;
    var replacement: [64]erfa.LeapSecond = undefined;
    if (builtin.len + 2 > replacement.len) return error.ReplacementTooSmall;
    @memcpy(replacement[0..builtin.len], builtin);
    replacement[builtin.len] = .{ .iyear = 2020, .month = 1, .delat = 38.0 };
    replacement[builtin.len + 1] = .{ .iyear = 2022, .month = 7, .delat = 39.0 };
    erfa.leap.setLeapSeconds(replacement[0 .. builtin.len + 2]);
    defer erfa.leap.setLeapSeconds(null);

    const borrowed = erfa.leap.getLeapSeconds().entries orelse return error.MissingOutput;
    try testing.expectEqual(builtin.len + 2, borrowed.len);
    try expectNear(37.0, erfa.timescale.dat(2019, 6, 1, 0.0).delta_at, 0.0);
    try expectNear(38.0, erfa.timescale.dat(2021, 6, 1, 0.0).delta_at, 0.0);
    try expectNear(39.0, erfa.timescale.dat(2023, 6, 1, 0.0).delta_at, 0.0);

    // Mutating between calls verifies that the table pointer is retained.
    replacement[builtin.len].delat = 40.0;
    try expectNear(40.0, erfa.timescale.dat(2021, 6, 1, 0.0).delta_at, 0.0);

    // `null` resets the table to upstream's built-in data.
    erfa.leap.setLeapSeconds(null);
    const restored = erfa.leap.getLeapSeconds();
    try testing.expectEqual(@as(usize, 42), (restored.entries orelse return error.MissingOutput).len);
    try expectNear(37.0, erfa.timescale.dat(2023, 6, 1, 0.0).delta_at, 0.0);
}

/// Site conditions used by upstream's astrometry validation cases.
const sofa_site = erfa.Observatory{
    .delta_ut1 = 0.1550675,
    .longitude = -0.527800806,
    .latitude = -1.2345856,
    .height = 2738.0,
    .polar_motion_x = 2.47230737e-7,
    .polar_motion_y = 1.82640464e-6,
    .pressure = 731.0,
    .temperature = 12.8,
    .humidity = 0.59,
    .wavelength = 0.55,
};

/// UTC quasi-JD used in those cases, in the Julian Day Number split.
const sofa_utc = erfa.Date2{ .part_a = 2456384.5, .part_b = 0.969254051 };

test "rotation: SOFA values for the rotation angle and the sidereal times" {
    nativeReady();

    try expectNear(0.4022837240028158102, erfa.rotation.earthRotationAngle(.{ .part_a = 2400000.5, .part_b = 54388.0 }), 1e-12);

    const ut1 = erfa.Date2{ .part_a = 2400000.5, .part_b = 53736.0 };
    try expectNear(1.754174972210740592, erfa.rotation.gmst00(ut1, ut1), 1e-12);
    try expectNear(1.754174971870091203, erfa.rotation.gmst06(ut1, ut1), 1e-12);
    try expectNear(1.754174981860675096, erfa.rotation.gmst82(ut1), 1e-12);
    try expectNear(1.754166138018281369, erfa.rotation.gst00a(ut1, ut1), 1e-12);
    try expectNear(1.754166136510680589, erfa.rotation.gst00b(ut1), 1e-12);
    try expectNear(1.754166137675019159, erfa.rotation.gst06a(ut1, ut1), 1e-12);
    try expectNear(1.754166136020645203, erfa.rotation.gst94(ut1), 1e-12);
}

test "rotation: every sidereal angle is normalised into [0, 2pi)" {
    nativeReady();

    const ut1 = erfa.Date2{ .part_a = 2456384.5, .part_b = 0.969254051 };
    const tt = erfa.Date2{ .part_a = 2456384.5, .part_b = 0.969254051 };
    const two_pi = 2.0 * std.math.pi;
    const angles = [_]f64{
        erfa.rotation.earthRotationAngle(ut1),
        erfa.rotation.gmst00(ut1, tt),
        erfa.rotation.gmst06(ut1, tt),
        erfa.rotation.gmst82(ut1),
        erfa.rotation.gst00a(ut1, tt),
        erfa.rotation.gst00b(ut1),
        erfa.rotation.gst06a(ut1, tt),
        erfa.rotation.gst94(ut1),
    };
    for (angles) |angle| {
        if (angle < 0.0 or angle >= two_pi) return error.AngleNotNormalised;
    }
}

test "rotation.gst06: SOFA value from a caller-supplied bpn matrix" {
    nativeReady();

    const rnpb = erfa.Mat3{
        .{ 0.9999989440476103608, -0.1332881761240011518e-2, -0.5790767434730085097e-3 },
        .{ 0.1332858254308954453e-2, 0.9999991109044505944, -0.4097782710401555759e-4 },
        .{ 0.5791308472168153320e-3, 0.4020595661593994396e-4, 0.9999998314954572365 },
    };
    const ut1 = erfa.Date2{ .part_a = 2400000.5, .part_b = 53736.0 };
    try expectNear(1.754166138018167568, erfa.rotation.gst06(ut1, ut1, &rnpb), 1e-12);
}

test "rotation: SOFA values for the equation of the equinoxes" {
    nativeReady();

    const epoch = erfa.Date2{ .part_a = 2400000.5, .part_b = 53736.0 };
    try expectNear(-0.8834193235367965479e-5, erfa.rotation.ee00(epoch, 0.4090789763356509900, -0.9630909107115582393e-5), 1e-18);
    try expectNear(-0.8834192459222588227e-5, erfa.rotation.ee00a(epoch), 1e-18);
    try expectNear(-0.8835700060003032831e-5, erfa.rotation.ee00b(epoch), 1e-18);
    try expectNear(-0.8834195072043790156e-5, erfa.rotation.ee06a(epoch), 1e-15);
    try expectNear(0.2046085004885125264e-8, erfa.rotation.eect00(epoch), 1e-20);
}

test "rotation.apco13: SOFA values and the equation of the origins" {
    nativeReady();

    const result = erfa.rotation.apco13(sofa_utc, sofa_site);
    try testing.expect(result.status.isOk());
    const astrom = result.astrom orelse return error.MissingOutput;
    try expectNear(13.25248468622475727, astrom.pmt, 1e-11);
    try expectNear(-0.9741827107320875162, astrom.eb[0], 1e-12);
    try expectNear(-0.9736425572586935247, astrom.eh[0], 1e-12);
    try expectNear(0.9998233240913898141, astrom.em, 1e-12);
    try expectNear(0.2078704994520489246e-4, astrom.v[0], 1e-16);
    try expectNear(2.617608909189664000, astrom.eral, 1e-12);
    try expectNear(-0.003020548354802412839, result.equation_of_origins orelse return error.MissingOutput, 1e-14);
}

test "rotation.apio13: SOFA values and the members it shares with apco13" {
    nativeReady();

    const result = erfa.rotation.apio13(sofa_utc, sofa_site);
    try testing.expect(result.status.isOk());
    const astrom = result.astrom orelse return error.MissingOutput;
    try expectNear(-0.5278008060295995733, astrom.along, 1e-12);
    try expectNear(0.1133427418130752958e-5, astrom.xpl, 1e-17);
    try expectNear(0.1453347595780646207e-5, astrom.ypl, 1e-17);
    try expectNear(-0.9440115679003211329, astrom.sphi, 1e-12);
    try expectNear(0.3299123514971474711, astrom.cphi, 1e-12);
    try expectNear(0.5135843661699913529e-6, astrom.diurab, 1e-12);
    try expectNear(0.2014187785940396921e-3, astrom.refa, 1e-15);
    try expectNear(-0.2361408314943696227e-6, astrom.refb, 1e-18);

    // `apio13` and `apco13` share the CIRS rotation but differ in diurnal aberration.
    // `apio13` returns only the nine fields it initializes.
    const full = erfa.rotation.apco13(sofa_utc, sofa_site);
    const complete = full.astrom orelse return error.MissingOutput;
    try expectNear(complete.along, astrom.along, 0.0);
    try expectNear(complete.xpl, astrom.xpl, 0.0);
    try expectNear(complete.ypl, astrom.ypl, 0.0);
    try expectNear(complete.sphi, astrom.sphi, 0.0);
    try expectNear(complete.cphi, astrom.cphi, 0.0);
    try expectNear(complete.eral, astrom.eral, 0.0);
    try expectNear(complete.refa, astrom.refa, 0.0);
    try expectNear(complete.refb, astrom.refb, 0.0);
    if (astrom.diurab == complete.diurab) return error.DiurnalAberrationWasNotComputed;
}

test "rotation.atco13: SOFA values" {
    nativeReady();

    const result = erfa.rotation.atco13(
        .{ .first = 2.71, .second = 0.174 },
        .{ .first = 1e-5, .second = 5e-6 },
        0.1,
        55.0,
        sofa_utc,
        sofa_site,
    );
    try testing.expect(result.status.isOk());
    const place = result.place orelse return error.MissingOutput;
    try expectNear(0.9251774485485515207e-1, place.azimuth, 1e-12);
    try expectNear(1.407661405256499357, place.zenith_distance, 1e-12);
    try expectNear(-0.9265154431529724692e-1, place.hour_angle, 1e-12);
    try expectNear(0.1716626560072526200, place.declination, 1e-12);
    try expectNear(2.710260453504961012, place.right_ascension, 1e-12);
    try expectNear(-0.003020548354802412839, result.equation_of_origins orelse return error.MissingOutput, 1e-14);
}

test "rotation.atio13: SOFA values" {
    nativeReady();

    const result = erfa.rotation.atio13(sofa_utc, sofa_site, .{ .first = 2.710121572969038991, .second = 0.1729371367218230438 });
    try testing.expect(result.status.isOk());
    const place = result.place orelse return error.MissingOutput;
    try expectNear(0.9233952224895122499e-1, place.azimuth, 1e-12);
    try expectNear(1.407758704513549991, place.zenith_distance, 1e-12);
    try expectNear(-0.9247619879881698140e-1, place.hour_angle, 1e-12);
    try expectNear(0.1717653435756234676, place.declination, 1e-12);
    try expectNear(2.710085107988480746, place.right_ascension, 1e-12);
}

test "rotation.atoc13 and atoi13: SOFA values for all three coordinate kinds" {
    nativeReady();

    // `atoc13` returns ICRS coordinates; `atoi13` returns CIRS coordinates.
    const cases = [_]struct {
        kind: erfa.ObservationType,
        first: f64,
        second: f64,
        icrs_ra: f64,
        icrs_dec: f64,
        cirs_ra: f64,
        cirs_dec: f64,
    }{
        .{
            .kind = .right_ascension,
            .first = 2.710085107986886201,
            .second = 0.1717653435758265198,
            .icrs_ra = 2.709956744659136129,
            .icrs_dec = 0.1741696500898471362,
            .cirs_ra = 2.710121574447540810,
            .cirs_dec = 0.1729371839116608778,
        },
        .{
            .kind = .hour_angle,
            .first = -0.09247619879782006106,
            .second = 0.1717653435758265198,
            .icrs_ra = 2.709956744659734086,
            .icrs_dec = 0.1741696500898471362,
            .cirs_ra = 2.710121574448138676,
            .cirs_dec = 0.1729371839116608778,
        },
        .{
            .kind = .azimuth,
            .first = 0.09233952224794989993,
            .second = 1.407758704513722461,
            .icrs_ra = 2.709956744659734086,
            .icrs_dec = 0.1741696500898471366,
            .cirs_ra = 2.710121574448138676,
            .cirs_dec = 0.1729371839116608781,
        },
    };
    for (cases) |case| {
        const observed = erfa.ObservedSpherical{ .first = case.first, .second = case.second };

        const to_icrs = erfa.rotation.atoc13(case.kind, observed, sofa_utc, sofa_site);
        try testing.expect(to_icrs.status.isOk());
        const icrs = to_icrs.icrs orelse return error.MissingOutput;
        try expectNear(case.icrs_ra, icrs.first, 1e-12);
        try expectNear(case.icrs_dec, icrs.second, 1e-12);

        const to_cirs = erfa.rotation.atoi13(case.kind, observed, sofa_utc, sofa_site);
        try testing.expect(to_cirs.status.isOk());
        const cirs = to_cirs.cirs orelse return error.MissingOutput;
        try expectNear(case.cirs_ra, cirs.first, 1e-12);
        try expectNear(case.cirs_dec, cirs.second, 1e-12);
    }
}

test "rotation: an unacceptable date leaves the astrometry outputs absent" {
    nativeReady();

    const bad = erfa.Date2{ .part_a = -1e10, .part_b = 0.0 };
    const apco = erfa.rotation.apco13(bad, sofa_site);
    try testing.expectEqual(@as(i32, -1), apco.status.value);
    try testing.expect(apco.astrom == null);
    try testing.expect(apco.equation_of_origins == null);

    const apio = erfa.rotation.apio13(bad, sofa_site);
    try testing.expect(apio.astrom == null);

    const atco = erfa.rotation.atco13(
        .{ .first = 2.71, .second = 0.174 },
        .{ .first = 0.0, .second = 0.0 },
        0.1,
        55.0,
        bad,
        sofa_site,
    );
    try testing.expect(atco.place == null);
    try testing.expect(atco.equation_of_origins == null);

    const atio = erfa.rotation.atio13(bad, sofa_site, .{ .first = 2.71, .second = 0.174 });
    try testing.expect(atio.place == null);

    try testing.expect(erfa.rotation.atoc13(.azimuth, .{ .first = 0.1, .second = 1.4 }, bad, sofa_site).icrs == null);
    try testing.expect(erfa.rotation.atoi13(.azimuth, .{ .first = 0.1, .second = 1.4 }, bad, sofa_site).cirs == null);
}

test "geodetic.eform: SOFA values for all three ellipsoids" {
    nativeReady();

    const wgs84 = erfa.geodetic.eform(.wgs84);
    try testing.expect(wgs84.status.isOk());
    try expectNear(6378137.0, wgs84.equatorial_radius, 1e-10);
    try expectNear(0.3352810664747480720e-2, wgs84.flattening, 1e-18);

    const grs80 = erfa.geodetic.eform(.grs80);
    try testing.expect(grs80.status.isOk());
    try expectNear(6378137.0, grs80.equatorial_radius, 1e-10);
    try expectNear(0.3352810681182318935e-2, grs80.flattening, 1e-18);

    const wgs72 = erfa.geodetic.eform(.wgs72);
    try testing.expect(wgs72.status.isOk());
    try expectNear(6378135.0, wgs72.equatorial_radius, 1e-10);
    try expectNear(0.3352779454167504862e-2, wgs72.flattening, 1e-18);
}

test "geodetic.gc2gd and gc2gde: SOFA values, and gc2gde reports an illegal ellipsoid by absence" {
    nativeReady();

    const cartesian = erfa.Vec3{ 2e6, 3e6, 5.244e6 };

    const wgs84 = erfa.geodetic.gc2gd(.wgs84, &cartesian);
    try testing.expect(wgs84.status.isOk());
    try expectNear(0.9827937232473290680, wgs84.geodetic.longitude, 1e-14);
    try expectNear(0.97160184819075459, wgs84.geodetic.latitude, 1e-14);
    try expectNear(331.4172461426059892, wgs84.geodetic.height, 1e-8);

    const grs80 = erfa.geodetic.gc2gd(.grs80, &cartesian);
    try expectNear(0.97160184820607853, grs80.geodetic.latitude, 1e-14);
    try expectNear(331.41731754844348, grs80.geodetic.height, 1e-8);

    const wgs72 = erfa.geodetic.gc2gd(.wgs72, &cartesian);
    try expectNear(0.9716018181101511937, wgs72.geodetic.latitude, 1e-14);
    try expectNear(333.2770726130318123, wgs72.geodetic.height, 1e-8);

    // The general form yields the same longitude with a slightly different flattening.
    const general = erfa.geodetic.gc2gde(6378136.0, 0.0033528, &cartesian);
    const geodetic = general.geodetic orelse return error.MissingOutput;
    try expectNear(0.9827937232473290680, geodetic.longitude, 1e-14);
    try expectNear(0.9716018377570411532, geodetic.latitude, 1e-14);
    try expectNear(332.36862495764397, geodetic.height, 1e-8);

    // Invalid flattening returns `-1` without an output.
    const bad_flat = erfa.geodetic.gc2gde(6378136.0, 1.5, &cartesian);
    try testing.expectEqual(@as(i32, -1), bad_flat.status.value);
    try testing.expect(bad_flat.geodetic == null);

    const bad_radius = erfa.geodetic.gc2gde(0.0, 0.0033528, &cartesian);
    try testing.expectEqual(@as(i32, -2), bad_radius.status.value);
    try testing.expect(bad_radius.geodetic == null);
}

test "geodetic.gd2gc and gd2gce: SOFA values" {
    nativeReady();

    const position = erfa.Geodetic{ .longitude = 3.1, .latitude = -0.5, .height = 2500.0 };

    const wgs84 = erfa.geodetic.gd2gc(.wgs84, position);
    try testing.expect(wgs84.status.isOk());
    try expectNear(-5599000.5577049947, wgs84.cartesian[0], 1e-7);
    try expectNear(233011.67223479203, wgs84.cartesian[1], 1e-7);
    try expectNear(-3040909.4706983363, wgs84.cartesian[2], 1e-7);

    const grs80 = erfa.geodetic.gd2gc(.grs80, position);
    try expectNear(-5599000.5577260984, grs80.cartesian[0], 1e-7);
    try expectNear(-3040909.4706095476, grs80.cartesian[2], 1e-7);

    const wgs72 = erfa.geodetic.gd2gc(.wgs72, position);
    try expectNear(-5598998.7626301490, wgs72.cartesian[0], 1e-7);
    try expectNear(233011.5975297822211, wgs72.cartesian[1], 1e-7);
    try expectNear(-3040908.6861467111, wgs72.cartesian[2], 1e-7);

    const general = erfa.geodetic.gd2gce(6378136.0, 0.0033528, position);
    const cartesian = general.cartesian orelse return error.MissingOutput;
    try expectNear(-5598999.6665116328, cartesian[0], 1e-7);
    try expectNear(233011.6351463057189, cartesian[1], 1e-7);
    try expectNear(-3040909.0517314132, cartesian[2], 1e-7);
}

test "geodetic: the inverse transformation round-trips within its own accuracy" {
    nativeReady();

    const original = erfa.Geodetic{ .longitude = 3.1, .latitude = -0.5, .height = 2500.0 };
    const cartesian = erfa.geodetic.gd2gc(.wgs84, original).cartesian;
    const back = erfa.geodetic.gc2gd(.wgs84, &cartesian).geodetic;
    try expectNear(original.longitude, back.longitude, 1e-11);
    try expectNear(original.latitude, back.latitude, 1e-11);
    try expectNear(original.height, back.height, 1e-6);
}

test "geodetic: no coordinate or ellipsoid validation is invented" {
    nativeReady();

    // `gd2gc` does not validate longitude, latitude or height.
    const absurd = erfa.geodetic.gd2gc(.wgs84, .{ .longitude = 0.0, .latitude = 100.0, .height = -1e9 });
    try testing.expect(absurd.status.isOk());
    // `gd2gce` also accepts flattening 2.0; only its divisor guard can fail.
    const accepted = erfa.geodetic.gd2gce(6378136.0, 2.0, .{ .longitude = 0.0, .latitude = 0.0, .height = 0.0 });
    try testing.expect(accepted.status.isOk());
    const cartesian = accepted.cartesian orelse return error.MissingOutput;
    try expectNear(6378136.0, cartesian[0], 1e-9);
    try expectNear(0.0, cartesian[1], 0.0);
    try expectNear(0.0, cartesian[2], 0.0);
}

test "precession: SOFA values for the obliquities, the two equinox angles and nutation" {
    nativeReady();

    const epoch = erfa.Date2{ .part_a = 2400000.5, .part_b = 54388.0 };
    const nutation_epoch = erfa.Date2{ .part_a = 2400000.5, .part_b = 53736.0 };

    try expectNear(0.4090749229387258204, erfa.precession.obl06(epoch), 1e-14);
    try expectNear(0.4090751347643816218, erfa.precession.obl80(epoch), 1e-14);
    // Upstream's `eqeq94` validation case uses MJD 41234.0.
    try expectNear(0.5357758254609256894e-4, erfa.precession.eqeq94(.{ .part_a = 2400000.5, .part_b = 41234.0 }), 1e-17);
    try expectNear(-0.1332882371941833644e-2, erfa.precession.eo06a(nutation_epoch), 1e-15);

    const rnpb = erfa.Mat3{
        .{ 0.9999989440476103608, -0.1332881761240011518e-2, -0.5790767434730085097e-3 },
        .{ 0.1332858254308954453e-2, 0.9999991109044505944, -0.4097782710401555759e-4 },
        .{ 0.5791308472168153320e-3, 0.4020595661593994396e-4, 0.9999998314954572365 },
    };
    try expectNear(-0.1332882715130744606e-2, erfa.precession.eors(&rnpb, -0.1220040848472271978e-7), 1e-14);

    const nut00a = erfa.precession.nut00a(nutation_epoch);
    try expectNear(-0.9630909107115518431e-5, nut00a.dpsi, 1e-13);
    try expectNear(0.4063239174001678710e-4, nut00a.deps, 1e-13);

    const nut00b = erfa.precession.nut00b(nutation_epoch);
    try expectNear(-0.9632552291148362783e-5, nut00b.dpsi, 1e-13);
    try expectNear(0.4063197106621159367e-4, nut00b.deps, 1e-13);

    const nut06a = erfa.precession.nut06a(nutation_epoch);
    try expectNear(-0.9630912025820308797e-5, nut06a.dpsi, 1e-13);
    try expectNear(0.4063238496887249798e-4, nut06a.deps, 1e-13);

    const nut80 = erfa.precession.nut80(nutation_epoch);
    try expectNear(-0.9643658353226563966e-5, nut80.dpsi, 1e-13);
    try expectNear(0.4060051006879713322e-4, nut80.deps, 1e-13);
}

test "precession: SOFA values for the nutation rotation matrices" {
    nativeReady();

    const epoch = erfa.Date2{ .part_a = 2400000.5, .part_b = 53736.0 };

    const num00a = erfa.precession.num00a(epoch);
    try expectNear(0.9999999999536227949, num00a[0][0], 1e-12);
    try expectNear(0.8836238544090873336e-5, num00a[0][1], 1e-12);
    try expectNear(0.3830835237722400669e-5, num00a[0][2], 1e-12);

    const num00b = erfa.precession.num00b(epoch);
    try expectNear(0.9999999999536069682, num00b[0][0], 1e-12);
    try expectNear(0.8837746144871248011e-5, num00b[0][1], 1e-12);
    try expectNear(0.3831488838252202945e-5, num00b[0][2], 1e-12);

    const num06a = erfa.precession.num06a(epoch);
    try expectNear(0.9999999999536227668, num06a[0][0], 1e-12);
    try expectNear(0.8836241998111535233e-5, num06a[0][1], 1e-12);
    try expectNear(0.3830834608415287707e-5, num06a[0][2], 1e-12);

    const nutm80 = erfa.precession.nutm80(epoch);
    try expectNear(0.9999999999534999268, nutm80[0][0], 1e-12);
    try expectNear(0.8847935789636432161e-5, nutm80[0][1], 1e-12);
    try expectNear(0.3835906502164019142e-5, nutm80[0][2], 1e-12);
}

test "precession: SOFA values for the Fukushima-Williams angles" {
    nativeReady();

    const gamma_bar = -0.2243387670997992368e-5;
    const phi_bar = 0.4091014602391312982;
    const psi = -0.9501954178013015092e-3;
    const epsilon = 0.4091014316587367472;

    const matrix = erfa.precession.fw2m(gamma_bar, phi_bar, psi, epsilon);
    const expected = erfa.Mat3{
        .{ 0.9999995505176007047, 0.8695404617348192957e-3, 0.3779735201865582571e-3 },
        .{ -0.8695404723772016038e-3, 0.9999996219496027161, -0.1361752496887100026e-6 },
        .{ -0.3779734957034082790e-3, -0.1924880848087615651e-6, 0.9999999285679971958 },
    };
    for (0..3) |row| {
        for (0..3) |column| {
            try expectNear(expected[row][column], matrix[row][column], 1e-12);
        }
    }

    const cip = erfa.precession.fw2xy(gamma_bar, phi_bar, psi, epsilon);
    try expectNear(-0.3779734957034082790e-3, cip.x, 1e-14);
    try expectNear(-0.1924880848087615651e-6, cip.y, 1e-14);
}

test "precession: SOFA values for pn00, pn06 and the a/b models" {
    nativeReady();

    const epoch = erfa.Date2{ .part_a = 2400000.5, .part_b = 53736.0 };
    const dpsi = -0.9632552291149335877e-5;
    const deps = 0.4063197106621141414e-4;

    // `pn00` and `pn06` take nutation angles as input and return rotations.
    const pn00 = erfa.precession.pn00(epoch, dpsi, deps);
    try expectNear(0.4090791789404229916, pn00.epsa, 1e-12);
    try expectNear(0.9999999999999942498, pn00.rb[0][0], 1e-12);
    try expectNear(-0.7078279744199196626e-7, pn00.rb[0][1], 1e-18);
    try expectNear(0.9999989300532289018, pn00.rp[0][0], 1e-12);
    try expectNear(0.9999999999536069682, pn00.rn[0][0], 1e-12);
    try expectNear(0.9999989440499982806, pn00.rbpn[0][0], 1e-12);

    const pn06 = erfa.precession.pn06(epoch, dpsi, deps);
    try expectNear(0.4090789763356509926, pn06.epsa, 1e-12);
    try expectNear(-0.7078368960971557145e-7, pn06.rb[0][1], 1e-14);
    try expectNear(0.9999989440504506688, pn06.rbpn[0][0], 1e-12);

    const pn00a = erfa.precession.pn00a(epoch);
    try expectNear(-0.9630909107115518431e-5, pn00a.dpsi, 1e-12);
    try expectNear(0.4063239174001678710e-4, pn00a.deps, 1e-12);
    try expectNear(0.4090791789404229916, pn00a.epsa, 1e-12);

    const pn00b = erfa.precession.pn00b(epoch);
    try expectNear(-0.9632552291148362783e-5, pn00b.dpsi, 1e-12);
    try expectNear(0.4063197106621159367e-4, pn00b.deps, 1e-12);

    const pn06a = erfa.precession.pn06a(epoch);
    try expectNear(-0.9630912025820308797e-5, pn06a.dpsi, 1e-12);
    try expectNear(0.4063238496887249798e-4, pn06a.deps, 1e-12);
    try expectNear(0.4090789763356509926, pn06a.epsa, 1e-12);
}

test "precession: SOFA values for the combined matrices" {
    nativeReady();

    const epoch = erfa.Date2{ .part_a = 2400000.5, .part_b = 50123.9999 };

    const pnm00a = erfa.precession.pnm00a(epoch);
    try expectNear(0.9999995832793134257, pnm00a[0][0], 1e-12);
    try expectNear(0.8372384254137809439e-3, pnm00a[0][1], 1e-14);

    const pnm00b = erfa.precession.pnm00b(epoch);
    try expectNear(0.9999995832776208280, pnm00b[0][0], 1e-12);
    try expectNear(0.8372401264429654837e-3, pnm00b[0][1], 1e-14);

    const pnm06a = erfa.precession.pnm06a(epoch);
    try expectNear(0.9999995832794205484, pnm06a[0][0], 1e-12);
    try expectNear(0.8372382772630962111e-3, pnm06a[0][1], 1e-14);

    const pnm80 = erfa.precession.pnm80(epoch);
    try expectNear(0.9999995831934611169, pnm80[0][0], 1e-12);
    try expectNear(0.8373654045728124011e-3, pnm80[0][1], 1e-14);

    const pmat00 = erfa.precession.pmat00(epoch);
    try expectNear(0.9999995505175087260, pmat00[0][0], 1e-12);
    try expectNear(0.8695405883617884705e-3, pmat00[0][1], 1e-14);

    const pmat06 = erfa.precession.pmat06(epoch);
    try expectNear(0.9999995505176007047, pmat06[0][0], 1e-12);
    try expectNear(0.8695404617348208406e-3, pmat06[0][1], 1e-14);

    const pmat76 = erfa.precession.pmat76(epoch);
    try expectNear(0.9999995504328350733, pmat76[0][0], 1e-12);
    try expectNear(0.8696632209480960785e-3, pmat76[0][1], 1e-14);
}

test "precession: SOFA values for polar motion and the 1976 angles" {
    nativeReady();

    const polar = erfa.precession.pom00(2.55060238e-7, 1.860359247e-6, -0.1367174580728891460e-10);
    try expectNear(0.9999999999999674721, polar[0][0], 1e-12);
    try expectNear(-0.1367174580728846989e-10, polar[0][1], 1e-16);
    try expectNear(0.2550602379999972345e-6, polar[0][2], 1e-16);
    try expectNear(0.1414624947957029801e-10, polar[1][0], 1e-16);
    try expectNear(-0.1860359246998866389e-5, polar[1][2], 1e-16);

    const angles = erfa.precession.prec76(
        .{ .part_a = 2400000.5, .part_b = 33282.0 },
        .{ .part_a = 2400000.5, .part_b = 51544.0 },
    );
    try expectNear(0.5588961642000161243e-2, angles.zeta, 1e-12);
    try expectNear(0.5589922365870680624e-2, angles.z, 1e-12);
}

test "precession: SOFA values for the Lieske long-term models" {
    nativeReady();

    const ltecm_matrix = erfa.precession.ltecm(-3000.0);
    try expectNear(0.3564105644859788825, ltecm_matrix[0][0], 1e-14);
    try expectNear(0.8530575738617682284, ltecm_matrix[0][1], 1e-14);
    try expectNear(0.3811355207795060435, ltecm_matrix[0][2], 1e-14);

    const ecliptic = erfa.precession.lteqec(-1500.0, .{ .right_ascension = 1.234, .declination = 0.987 });
    try expectNear(0.5039483649047114859, ecliptic.longitude, 1e-14);
    try expectNear(0.5848534459726224882, ecliptic.latitude, 1e-14);

    const equatorial = erfa.precession.lteceq(2500.0, .{ .longitude = 1.5, .latitude = 0.6 });
    try expectNear(1.275156021861921167, equatorial.right_ascension, 1e-14);
    try expectNear(0.9966573543519204791, equatorial.declination, 1e-14);

    const ltp_matrix = erfa.precession.ltp(1666.666);
    try expectNear(0.9967044141159213819, ltp_matrix[0][0], 1e-14);
    try expectNear(0.7437801893193210840e-1, ltp_matrix[0][1], 1e-14);
    try expectNear(0.3237624409345603401e-1, ltp_matrix[0][2], 1e-14);

    const ltpb_matrix = erfa.precession.ltpb(1666.666);
    try expectNear(0.9967044167723271851, ltpb_matrix[0][0], 1e-14);
    try expectNear(0.7437794731203340345e-1, ltpb_matrix[0][1], 1e-14);
    try expectNear(0.3237632684841625547e-1, ltpb_matrix[0][2], 1e-14);

    const to_ecliptic = erfa.precession.ltpecl(-1500.0);
    try expectNear(0.4768625676477096525e-3, to_ecliptic[0], 1e-14);
    try expectNear(-0.4052259533091875112, to_ecliptic[1], 1e-14);
    try expectNear(0.9142164401096448012, to_ecliptic[2], 1e-14);

    const to_equatorial = erfa.precession.ltpequ(-2500.0);
    try expectNear(-0.3586652560237326659, to_equatorial[0], 1e-14);
    try expectNear(-0.1996978910771128475, to_equatorial[1], 1e-14);
    try expectNear(0.9118552442250819624, to_equatorial[2], 1e-14);
}

test "precession: every rotation matrix is orthonormal to its own accuracy" {
    nativeReady();

    // The rotation matrices satisfy `R R^T = I`.
    const epoch = erfa.Date2{ .part_a = 2400000.5, .part_b = 50123.9999 };
    const matrices = [_]erfa.Mat3{
        erfa.precession.num00a(epoch),
        erfa.precession.num00b(epoch),
        erfa.precession.num06a(epoch),
        erfa.precession.nutm80(epoch),
        erfa.precession.pnm00a(epoch),
        erfa.precession.pnm00b(epoch),
        erfa.precession.pnm06a(epoch),
        erfa.precession.pnm80(epoch),
        erfa.precession.pmat00(epoch),
        erfa.precession.pmat06(epoch),
        erfa.precession.pmat76(epoch),
        erfa.precession.ltp(1666.666),
        erfa.precession.ltpb(1666.666),
        erfa.precession.ltecm(-3000.0),
    };
    for (matrices) |matrix| {
        for (0..3) |row| {
            for (0..3) |column| {
                var dot: f64 = 0.0;
                for (0..3) |k| dot += matrix[row][k] * matrix[column][k];
                const want: f64 = if (row == column) 1.0 else 0.0;
                try expectNear(want, dot, 1e-12);
            }
        }
    }
}

test "ephemeris.epv00: SOFA values and the out-of-range warning" {
    nativeReady();

    const result = erfa.ephemeris.epv00(.{ .part_a = 2400000.5, .part_b = 53411.52501161 });
    try testing.expect(result.status.isOk());
    try expectNear(-0.7757238809297706813, result.heliocentric.position[0], 1e-14);
    try expectNear(0.5598052241363340596, result.heliocentric.position[1], 1e-14);
    try expectNear(0.2426998466481686993, result.heliocentric.position[2], 1e-14);
    try expectNear(-0.1091891824147313846e-1, result.heliocentric.velocity[0], 1e-15);
    try expectNear(-0.5407569418065039061e-2, result.heliocentric.velocity[2], 1e-15);
    try expectNear(-0.7714104440491111971, result.barycentric.position[0], 1e-14);
    try expectNear(0.5598412061824171323, result.barycentric.position[1], 1e-14);
    try expectNear(0.2425996277722452400, result.barycentric.position[2], 1e-14);
    try expectNear(-0.1091874268116823295e-1, result.barycentric.velocity[0], 1e-15);
    try expectNear(-0.5404773180966231279e-2, result.barycentric.velocity[2], 1e-15);

    // Outside 1900-2100 the warning `+1` retains both vectors.
    const far = erfa.ephemeris.epv00(.{ .part_a = 6200000.0, .part_b = 0.0 });
    try testing.expect(far.status.isWarning());
    try testing.expectEqual(@as(i32, 1), far.status.value);
    for ([_]f64{ far.heliocentric.position[0], far.barycentric.position[0] }) |value| {
        if (!std.math.isFinite(value)) return error.NonFiniteEphemeris;
    }
}

test "ephemeris.plan94: SOFA values and the whole status ladder" {
    nativeReady();

    // Invalid planet ids return `-1` and zero all six components.
    for ([_]i32{ 0, 10 }) |planet| {
        const rejected = erfa.ephemeris.plan94(.{ .part_a = 2400000.5, .part_b = 1e6 }, planet);
        try testing.expectEqual(@as(i32, -1), rejected.status.value);
        for (rejected.pv.position) |component| try expectNear(0.0, component, 0.0);
        for (rejected.pv.velocity) |component| try expectNear(0.0, component, 0.0);
    }

    // Outside years 1000-3000, warning `+1` still returns a vector.
    const warned = erfa.ephemeris.plan94(.{ .part_a = 2400000.5, .part_b = -320000.0 }, 3);
    try testing.expectEqual(@as(i32, 1), warned.status.value);
    try expectNear(0.9308038666832975759, warned.pv.position[0], 1e-11);
    try expectNear(0.3258319040261346000, warned.pv.position[1], 1e-11);
    try expectNear(0.1422794544481140560, warned.pv.position[2], 1e-11);
    try expectNear(-0.6429458958255170006e-2, warned.pv.velocity[0], 1e-11);
    try expectNear(0.6406996426270981189e-2, warned.pv.velocity[2], 1e-11);

    // Valid-range dates return status zero.
    const earth = erfa.ephemeris.plan94(.{ .part_a = 2400000.5, .part_b = 43999.9 }, 1);
    try testing.expect(earth.status.isOk());
    try expectNear(0.2945293959257430832, earth.pv.position[0], 1e-11);
    try expectNear(-0.2452204176601049596, earth.pv.position[1], 1e-11);
    try expectNear(-0.1615427700571978153, earth.pv.position[2], 1e-11);
    try expectNear(0.1413867871404614441e-1, earth.pv.velocity[0], 1e-11);
    try expectNear(0.8929809783898904786e-2, earth.pv.velocity[2], 1e-11);
}

test "ephemeris.moon98: SOFA value" {
    nativeReady();

    const moon = erfa.ephemeris.moon98(.{ .part_a = 2400000.5, .part_b = 43999.9 });
    try expectNear(-0.2601295959971044180e-2, moon.position[0], 1e-11);
    try expectNear(0.6139750944302742189e-3, moon.position[1], 1e-11);
    try expectNear(0.2640794528229828909e-3, moon.position[2], 1e-11);
    try expectNear(-0.1244321506649895021e-3, moon.velocity[0], 1e-11);
    try expectNear(-0.5219076942678119398e-3, moon.velocity[1], 1e-11);
    try expectNear(-0.1716132214378462047e-3, moon.velocity[2], 1e-11);
}

test "vectors: SOFA values for pn, pm and ld" {
    nativeReady();

    const p = erfa.Vec3{ 0.3, 1.2, -2.5 };
    const parts = erfa.vectors.pn(&p);
    try expectNear(2.789265136196270604, parts.modulus, 1e-12);
    try expectNear(0.1075552109073112058, parts.unit[0], 1e-12);
    try expectNear(0.4302208436292448232, parts.unit[1], 1e-12);
    try expectNear(-0.8962934242275933816, parts.unit[2], 1e-12);

    // `pn` and `pm` must report the same modulus.
    try expectNear(parts.modulus, erfa.vectors.pm(&p), 1e-15);

    const deflected = erfa.vectors.ld(
        0.00028574,
        &.{ -0.763276255, -0.608633767, -0.216735543 },
        &.{ -0.763276255, -0.608633767, -0.216735543 },
        &.{ 0.76700421, 0.605629598, 0.211937094 },
        8.91276983,
        3e-10,
    );
    try expectNear(-0.7632762548968159627, deflected[0], 1e-12);
    try expectNear(-0.6086337670823762701, deflected[1], 1e-12);
    try expectNear(-0.2167355431320546947, deflected[2], 1e-12);
}

test "vectors: the zero vector has no direction and that is not an error" {
    nativeReady();

    const zero = erfa.Vec3{ 0.0, 0.0, 0.0 };
    const parts = erfa.vectors.pn(&zero);
    try expectNear(0.0, parts.modulus, 0.0);
    for (parts.unit) |component| try expectNear(0.0, component, 0.0);
}

test "vectors.s2xpv: two scalars, two members, six results" {
    nativeReady();

    // `s2xpv` scales position and velocity separately and returns both members.
    // Different exact scales and unrelated vectors distinguish all six components.
    const pv = erfa.Pv{
        .position = .{ 0.25, -0.5, 2.0 },
        .velocity = .{ -0.7, 0.4, 1.1 },
    };
    const scaled = erfa.vectors.s2xpv(3.0, -0.5, pv);

    try testing.expectEqual(@as(f64, 0.75), scaled.position[0]);
    try testing.expectEqual(@as(f64, -1.5), scaled.position[1]);
    try testing.expectEqual(@as(f64, 6.0), scaled.position[2]);
    try testing.expectEqual(@as(f64, 0.35), scaled.velocity[0]);
    try testing.expectEqual(@as(f64, -0.2), scaled.velocity[1]);
    try testing.expectEqual(@as(f64, -0.55), scaled.velocity[2]);
}

test "angles: pi radians is exactly 180 degrees and exactly 12 hours" {
    nativeReady();

    // A half-turn is exactly 180 degrees or 12 hours; leading fields are not wrapped.
    const degrees = erfa.angles.a2af(3, std.math.pi);
    try testing.expectEqual(@as(u8, '+'), degrees.sign);
    try testing.expectEqual(@as(i32, 180), degrees.degrees);
    try testing.expectEqual(@as(i32, 0), degrees.arcminutes);
    try testing.expectEqual(@as(i32, 0), degrees.arcseconds);
    try testing.expectEqual(@as(i32, 0), degrees.fraction);

    const hours = erfa.angles.a2tf(3, std.math.pi);
    try testing.expectEqual(@as(u8, '+'), hours.sign);
    try testing.expectEqual(@as(i32, 12), hours.hours);
    try testing.expectEqual(@as(i32, 0), hours.minutes);
    try testing.expectEqual(@as(i32, 0), hours.seconds);
    try testing.expectEqual(@as(i32, 0), hours.fraction);

    // `anp` and `anpm` use different ranges; `anpm(pi)` is `-pi`.
    try expectNear(2.0 * std.math.pi - 1.0, erfa.angles.anp(-1.0), 1e-15);
    try expectNear(-1.0, erfa.angles.anpm(-1.0), 1e-15);
    try expectNear(-std.math.pi, erfa.angles.anpm(std.math.pi), 1e-15);
}

test "matrices: a rotation is undone by its transpose" {
    nativeReady();

    const probe = erfa.Vec3{ 0.3, -1.2, 2.5 };
    const rotations = [_]erfa.Mat3{
        erfa.matrices.rotateX(0.7),
        erfa.matrices.rotateY(-1.3),
        erfa.matrices.rotateZ(2.1),
    };
    for (&rotations) |*rotation| {
        const transposed = erfa.matrices.transpose(rotation);
        const round_tripped = erfa.matrices.multiply(rotation, &transposed);
        for (0..3) |row| {
            for (0..3) |column| {
                try expectNear(if (row == column) 1.0 else 0.0, round_tripped[row][column], 1e-15);
            }
        }
        const turned = erfa.matrices.apply(rotation, &probe);
        for (probe, erfa.matrices.applyTransposed(rotation, &turned)) |want, got| {
            try expectNear(want, got, 1e-15);
        }
    }

    // Identity is the neutral matrix on both sides.
    const identity = erfa.matrices.identity();
    const on_the_left = erfa.matrices.multiply(&identity, &rotations[0]);
    const on_the_right = erfa.matrices.multiply(&rotations[0], &identity);
    for (0..3) |row| {
        for (0..3) |column| {
            const expected = rotations[0][row][column];
            try expectNear(expected, on_the_left[row][column], 1e-15);
            try expectNear(expected, on_the_right[row][column], 1e-15);
        }
    }
    for (erfa.matrices.zero()) |row| {
        for (row) |component| try testing.expectEqual(0.0, component);
    }
}

test "spherical: a unit direction decomposes back to its two angles" {
    nativeReady();

    // Cartesian conversion preserves the unnormalized fourth-quadrant angle.
    for ([_][2]f64{ .{ 0.3, -0.2 }, .{ -2.7, 1.2 }, .{ 5.9, 0.0 } }) |pair| {
        const vector = erfa.spherical.toCartesian(pair[0], pair[1]);
        const angles = erfa.spherical.fromCartesian(&vector);
        const rebuilt = erfa.spherical.toCartesian(angles.theta, angles.phi);
        for (vector, rebuilt) |expected, actual| {
            try expectNear(expected, actual, 1e-14);
        }
        try expectNear(pair[1], angles.phi, 1e-14);

        const scaled = erfa.spherical.toCartesianWithRadius(pair[0], pair[1], 5.0);
        try expectNear(5.0, erfa.vectors.pm(&scaled), 1e-14);
        const point = erfa.spherical.cartesianToSpherical(&scaled);
        try expectNear(5.0, point.radius, 1e-14);
    }

    // A zero vector yields two zero angles rather than an error.
    const zero = erfa.Vec3{ 0.0, 0.0, 0.0 };
    const degenerate = erfa.spherical.fromCartesian(&zero);
    try testing.expectEqual(0.0, degenerate.theta);
    try testing.expectEqual(0.0, degenerate.phi);
}

test "horizon: azimuth and elevation invert" {
    nativeReady();

    for ([_][2]f64{ .{ 1.1, 0.4 }, .{ 5.0, -0.3 }, .{ 0.2, 1.4 } }) |pair| {
        const horizontal = erfa.horizon.azimuthElevationToHorizontal(pair[0], pair[1], 0.8);
        const altitude = erfa.horizon.horizontalToAzimuthElevation(
            horizontal.first,
            horizontal.second,
            0.8,
        );
        try expectNear(pair[0], altitude.first, 1e-12);
        try expectNear(pair[1], altitude.second, 1e-12);
    }
}

test "gnomonic: the tangent plane projection inverts" {
    nativeReady();

    // `tpsts` and `tpxes` invert; `tpors` returns two solutions or none at the plane edge.
    const reference = erfa.StandardCoordinates{ .a = 0.3, .b = 0.2 };
    const tangent_point = erfa.gnomonic.toStandardCoordinates(0.01, 0.02, reference);
    const recovered = erfa.gnomonic.fromStandardCoordinatesInverse(tangent_point, reference);
    try testing.expect(recovered.status.isOk());
    try expectNear(0.01, recovered.coordinates.a, 1e-6);
    try expectNear(0.02, recovered.coordinates.b, 1e-6);

    const axis = erfa.Vec3{ 1.0, 0.0, 0.0 };
    const vector = erfa.gnomonic.toVector(0.01, 0.02, &axis);
    const vector_back = erfa.gnomonic.fromVectorInverse(&vector, &axis);
    try expectNear(0.01, vector_back.coordinates.a, 1e-6);
    try expectNear(0.02, vector_back.coordinates.b, 1e-6);

    const away = erfa.gnomonic.fromStandardCoordinates(0.01, 0.02, reference);
    try testing.expect(away.status.value > 0);
    try testing.expect(away.first != null and away.second != null);

    // A reference point on the plane edge gives no solutions.
    const on_the_plane = erfa.gnomonic.fromStandardCoordinates(
        0.01,
        0.02,
        .{ .a = 0.0, .b = std.math.pi / 2.0 },
    );
    try testing.expectEqual(@as(i32, 0), on_the_plane.status.value);
    try testing.expect(on_the_plane.first == null and on_the_plane.second == null);
}

test "star catalogues: FK5 and Hipparcos are each other's inverse" {
    nativeReady();

    const fk5 = erfa.StarMotion{
        .right_ascension = 1.1,
        .declination = 0.4,
        .pm_ra = 1e-5,
        .pm_dec = -2e-5,
        .parallax = 0.1,
        .radial_velocity = -20.0,
    };
    const hipparcos = erfa.starCatalogs.fk5ToHipparcos(fk5);
    const back = erfa.starCatalogs.hipparcosToFk5(hipparcos);
    try expectNear(fk5.right_ascension, back.right_ascension, 1e-9);
    try expectNear(fk5.declination, back.declination, 1e-9);
    try expectNear(fk5.pm_ra, back.pm_ra, 1e-12);
    try expectNear(fk5.pm_dec, back.pm_dec, 1e-12);
    try expectNear(fk5.parallax, back.parallax, 1e-9);

    // The opposite epoch transforms cancel their `-t` and `+t` rotations.
    const date = erfa.Date2{ .part_a = 2400000.5, .part_b = 53736.0 };
    const dated = erfa.starCatalogs.fk5ToHipparcosAtDate(fk5.right_ascension, fk5.declination, date);
    const dated_back = erfa.starCatalogs.hipparcosToFk5AtDate(dated.right_ascension, dated.declination, date);
    try expectNear(fk5.right_ascension, dated_back.right_ascension, 1e-12);
    try expectNear(fk5.declination, dated_back.declination, 1e-12);
}

test "leap seconds: the thread-local initialiser keeps what the thread already has" {
    nativeReady();

    // `datini` installs its argument only when no positive-count table is active.
    // A second call keeps the installed table; use `setLeapSeconds` to replace it.
    var replacement = [_]erfa.LeapSecond{.{ .iyear = 2000, .month = 1, .delat = 12.0 }};
    erfa.leap.setLeapSeconds(null);
    defer erfa.leap.setLeapSeconds(null);

    const installed = erfa.leap.datini(replacement[0..]);
    try testing.expectEqual(@as(i32, 1), installed.status.value);
    const installed_entries = installed.entries orelse return error.MissingOutput;
    try expectNear(12.0, installed_entries[0].delat, 0.0);

    // With a positive count, `datini(null)` retains the active table.
    const kept = erfa.leap.datini(null);
    try testing.expectEqual(@as(i32, 1), kept.status.value);
    try expectNear(12.0, (kept.entries orelse return error.MissingOutput)[0].delat, 0.0);
}

test "timescale: the periodic TDB-TT term is millisecond-scale" {
    nativeReady();

    // `eraDtdb` is a millisecond-scale approximation; check an Earth-observer result.
    const date = erfa.Date2{ .part_a = 2400000.5, .part_b = 53736.0 };
    for ([_][4]f64{
        .{ 0.0, 0.0, 4500.0, 1000.0 },
        .{ 0.5, 1.1, 6350.0, -2000.0 },
        .{ 0.25, -2.5, 6000.0, 0.0 },
    }) |observer| {
        const delta = erfa.timescale.dtdb(date, observer[0], observer[1], observer[2], observer[3]);
        try testing.expect(std.math.isFinite(delta));
        try testing.expect(@abs(delta) < 1e-2);
    }
}

test "fundamental arguments: the accumulated precession is zero at J2000.0" {
    nativeReady();

    // Accumulated precession is zero at J2000.0.
    try expectNear(0.0, erfa.fundamentalArgs.accumulatedPrecession(0.0), 1e-15);

    // The other arguments are finite polynomials in Julian centuries.
    const at_j2000 = [_]f64{
        erfa.fundamentalArgs.d(0.0),
        erfa.fundamentalArgs.earthLongitude(0.0),
        erfa.fundamentalArgs.f(0.0),
        erfa.fundamentalArgs.jupiterLongitude(0.0),
        erfa.fundamentalArgs.moonAnomaly(0.0),
        erfa.fundamentalArgs.sunAnomaly(0.0),
        erfa.fundamentalArgs.marsLongitude(0.0),
        erfa.fundamentalArgs.mercuryLongitude(0.0),
        erfa.fundamentalArgs.neptuneLongitude(0.0),
        erfa.fundamentalArgs.moonNode(0.0),
        erfa.fundamentalArgs.saturnLongitude(0.0),
        erfa.fundamentalArgs.uranusLongitude(0.0),
        erfa.fundamentalArgs.venusLongitude(0.0),
    };
    for (at_j2000) |value| try testing.expect(std.math.isFinite(value));
    try testing.expect(erfa.fundamentalArgs.sunAnomaly(1.0) != erfa.fundamentalArgs.sunAnomaly(0.0));
}
