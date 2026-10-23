//! Instantiates every public facade wrapper and checks independent invariants and known answers.
//! `tests.zig` holds SOFA validation cases; this module also runs as a standalone linked or runtime-loaded executable.

const std = @import("std");
const erfa = @import("erfa");

/// Failures this exercise can report: a contradictory result or missing output.
pub const Failure = error{
    /// A result disagreed with an invariant or reference value.
    UnexpectedResult,
    /// A wrapper's output availability disagreed with its status.
    MissingOutput,
};

/// Assert a condition, returning `UnexpectedResult` on failure.
fn expect(condition: bool) Failure!void {
    if (!condition) return error.UnexpectedResult;
}

/// Assert that two doubles agree within an absolute tolerance.
fn expectNear(expected: f64, actual: f64, tolerance: f64) Failure!void {
    if (std.math.approxEqAbs(f64, expected, actual, tolerance)) return;
    std.debug.print(
        "api_exercise: expected {d}, got {d}, within {d}\n",
        .{ expected, actual, tolerance },
    );
    return error.UnexpectedResult;
}

/// Assert that a rotation matrix is orthonormal.
fn expectOrthonormal(matrix: erfa.Mat3) Failure!void {
    for (0..3) |row| {
        for (0..3) |column| {
            var dot: f64 = 0.0;
            for (0..3) |k| dot += matrix[row][k] * matrix[column][k];
            const want: f64 = if (row == column) 1.0 else 0.0;
            try expectNear(want, dot, 1e-12);
        }
    }
}

/// Call every public facade method and verify independent behavior.
pub fn exercise() Failure!void {
    try exerciseLeapSeconds();
    try exerciseCalendar();
    try exerciseTimescales();
    try exerciseRotation();
    try exerciseGeodetic();
    try exercisePrecession();
    try exerciseEphemerides();
    try exerciseVectors();
    try exerciseExtendedSurface();
}

fn exerciseLeapSeconds() Failure!void {
    const borrowed = erfa.leap.getLeapSeconds();
    try expect(borrowed.status.value > 0);
    const entries = borrowed.entries orelse return error.MissingOutput;
    try expect(entries.len > 0);

    // The replacement must remain live because the facade retains its pointer.
    var replacement: [64]erfa.LeapSecond = undefined;
    if (entries.len + 2 > replacement.len) return error.UnexpectedResult;
    @memcpy(replacement[0..entries.len], entries);
    replacement[entries.len] = .{ .iyear = 2020, .month = 1, .delat = 38.0 };
    replacement[entries.len + 1] = .{ .iyear = 2022, .month = 7, .delat = 39.0 };
    erfa.leap.setLeapSeconds(replacement[0 .. entries.len + 2]);
    defer erfa.leap.setLeapSeconds(null);

    const replaced = erfa.leap.getLeapSeconds();
    try expect((replaced.entries orelse return error.MissingOutput).len == entries.len + 2);
    try expectNear(38.0, erfa.timescale.dat(2021, 6, 1, 0.0).delta_at, 0.0);
    try expectNear(39.0, erfa.timescale.dat(2023, 6, 1, 0.0).delta_at, 0.0);
    replacement[entries.len].delat = 40.0;
    try expectNear(40.0, erfa.timescale.dat(2021, 6, 1, 0.0).delta_at, 0.0);

    // Reset restores the built-in table.
    erfa.leap.setLeapSeconds(null);
    const restored = erfa.leap.getLeapSeconds();
    try expect((restored.entries orelse return error.MissingOutput).len > 2);
    try expectNear(37.0, erfa.timescale.dat(2020, 6, 1, 0.0).delta_at, 0.0);
}

fn exerciseCalendar() Failure!void {
    const converted = erfa.calendar.cal2jd(2003, 6, 1);
    try expect(converted.status.isOk());
    const mjd = converted.date orelse return error.MissingOutput;
    try expectNear(2400000.5, mjd.part_a, 0.0);
    try expectNear(52791.0, mjd.part_b, 0.0);

    // Check all three rejection statuses, including the invalid-day result.
    try expect(erfa.calendar.cal2jd(-4800, 1, 1).date == null);
    try expect(erfa.calendar.cal2jd(2003, 13, 1).date == null);
    const bad_day = erfa.calendar.cal2jd(2003, 2, 29);
    try expect(bad_day.status.isError());
    try expect(bad_day.date != null);

    const calendar_date = erfa.calendar.jd2cal(mjd);
    try expect(calendar_date.status.isOk());
    const back = calendar_date.date orelse return error.MissingOutput;
    try expect(back.year == 2003 and back.month == 6 and back.day == 1);
    try expect(back.fraction >= 0.0 and back.fraction < 1.0);
    try expect(erfa.calendar.jd2cal(.{ .part_a = -1e10, .part_b = 0.0 }).date == null);

    const rounded = erfa.calendar.jdcalf(4, mjd);
    try expect(rounded.status.isOk());
    const rounded_date = rounded.date orelse return error.MissingOutput;
    try expect(rounded_date.year == 2003);
    const bad_precision = erfa.calendar.jdcalf(11, mjd);
    try expect(bad_precision.status.isWarning());
    try expect(bad_precision.date != null);

    const encoded = erfa.calendar.dtf2d(.utc, 1994, 6, 30, 23, 59, 60.13599);
    try expect(encoded.status.isOk());
    try expectNear(2449534.49999, (encoded.date orelse return error.MissingOutput).sum(), 1e-6);
    const past_end = erfa.calendar.dtf2d(.utc, 1994, 6, 29, 23, 59, 60.5);
    try expect(past_end.status.isWarning());
    try expect(erfa.calendar.dtf2d(.utc, 2003, 6, 1, 24, 0, 0.0).date == null);

    const decoded = erfa.calendar.d2dtf(.utc, 5, .{ .part_a = 2400000.5, .part_b = 49533.99999 });
    try expect(decoded.status.isOk());
    const decoded_date = decoded.date orelse return error.MissingOutput;
    const decoded_time = decoded.time orelse return error.MissingOutput;
    try expect(decoded_date.year == 1994 and decoded_date.month == 6 and decoded_date.day == 30);
    try expect(decoded_time.hour == 23 and decoded_time.minute == 59 and decoded_time.second == 60);
    try expect(erfa.calendar.d2dtf(.utc, 5, .{ .part_a = -1e10, .part_b = 0.0 }).time == null);

    const fields = erfa.calendar.d2tf(4, -0.987654321);
    try expect(fields.sign == '-');
    try expect(fields.hour == 23 and fields.minute == 42 and fields.second == 13);

    try expectNear(0.9966539351851851852, erfa.calendar.tf2d(' ', 23, 55, 10.9).days, 1e-12);
    try expectNear(1.301739278189537429, erfa.calendar.tf2a('+', 4, 58, 20.2).radians, 1e-12);
    try expectNear(-0.7893115794313644842, erfa.calendar.af2a('-', 45, 13, 27.2).radians, 1e-12);
    try expect(erfa.calendar.tf2d('+', 24, 0, 0.0).status.isWarning());

    try expectNear(1982.418424159278580, erfa.calendar.epb(.{ .part_a = 2415019.8135, .part_b = 30103.18648 }), 1e-12);
    // Epoch conversions use Julian years from J2000, not MJD.
    const epb_date = erfa.calendar.epb2jd(1957.3);
    try expectNear(2400000.5, epb_date.part_a, 1e-9);
    try expectNear(35948.1915101513, epb_date.part_b, 1e-9);
    try expectNear(1979.760438056125941, erfa.calendar.epj(.{ .part_a = 2451545.0, .part_b = -7392.5 }), 1e-12);
    const epj_date = erfa.calendar.epj2jd(1996.8);
    try expectNear(2400000.5, epj_date.part_a, 1e-9);
    try expectNear(50375.7, epj_date.part_b, 1e-9);
}

fn exerciseTimescales() Failure!void {
    try expectNear(32.0, erfa.timescale.dat(2003, 6, 1, 0.0).delta_at, 0.0);
    try expect(erfa.timescale.dat(2029, 6, 1, 0.0).status.isWarning());
    try expect(erfa.timescale.dat(1959, 12, 31, 0.0).status.isWarning());
    try expect(erfa.timescale.dat(2003, 6, 1, 1.5).status.isError());

    // Compare date parts separately to preserve the two-part precision.
    const tai = erfa.Date2{ .part_a = 2453750.5, .part_b = 0.892482639 };
    const tai_utc = erfa.timescale.taiutc(tai);
    try expect(tai_utc.status.isOk());
    const utc = tai_utc.date orelse return error.MissingOutput;
    try expectNear(tai.part_a, utc.part_a, 1e-9);
    try expectNear(0.8921006945555555556, utc.part_b, 1e-12);

    const utc_tai = erfa.timescale.utctai(utc);
    try expect(utc_tai.status.isOk());
    try expectNear(tai.part_a, (utc_tai.date orelse return error.MissingOutput).part_a, 1e-9);
    try expectNear(tai.part_b, (utc_tai.date orelse return error.MissingOutput).part_b, 1e-9);

    const utc_ut1 = erfa.timescale.utcut1(utc, 0.3341);
    try expect(utc_ut1.status.isOk());
    const ut1 = utc_ut1.date orelse return error.MissingOutput;

    const ut1_utc = erfa.timescale.ut1utc(ut1, 0.3341);
    try expect(ut1_utc.status.isOk());
    try expectNear(utc.part_a, (ut1_utc.date orelse return error.MissingOutput).part_a, 1e-9);
    try expectNear(utc.part_b, (ut1_utc.date orelse return error.MissingOutput).part_b, 1e-12);
    try expect(erfa.timescale.utctai(.{ .part_a = -1e10, .part_b = 0.0 }).date == null);

    try expect(erfa.timescale.ut1tai(ut1, -32.6659).status.isOk());
    try expect(erfa.timescale.taiut1(tai, -32.6659).status.isOk());
    try expect(erfa.timescale.ut1tt(ut1, 64.8499).status.isOk());
    try expect(erfa.timescale.ttut1(ut1, 64.8499).status.isOk());

    // TT-TAI is exactly 32.184 s; the reverse conversion restores the split.
    const tt = erfa.timescale.taitt(tai).date orelse return error.MissingOutput;
    try expectNear(32.184 / 86400.0, tt.part_b - tai.part_b, 1e-12);
    const tai_again = erfa.timescale.tttai(tt).date orelse return error.MissingOutput;
    try expectNear(tai.part_a, tai_again.part_a, 0.0);
    try expectNear(tai.part_b, tai_again.part_b, 1e-12);

    const tcg = erfa.timescale.tttcg(tt).date orelse return error.MissingOutput;
    try expectNear(tt.part_b, (erfa.timescale.tcgtt(tcg).date orelse return error.MissingOutput).part_b, 1e-9);

    const tdb = erfa.timescale.tttdb(tt, -0.000201).date orelse return error.MissingOutput;
    try expectNear(tt.part_b, (erfa.timescale.tdbtt(tdb, -0.000201).date orelse return error.MissingOutput).part_b, 1e-9);
    try expectNear(tdb.part_b, (erfa.timescale.tcbtdb(erfa.timescale.tdbtcb(tdb).date orelse return error.MissingOutput).date orelse return error.MissingOutput).part_b, 1e-9);
}

fn exerciseRotation() Failure!void {
    const ut1 = erfa.Date2{ .part_a = 2400000.5, .part_b = 53736.0 };
    const two_pi = 2.0 * std.math.pi;

    const angles = [_]f64{
        erfa.rotation.earthRotationAngle(.{ .part_a = 2400000.5, .part_b = 54388.0 }),
        erfa.rotation.gmst00(ut1, ut1),
        erfa.rotation.gmst06(ut1, ut1),
        erfa.rotation.gmst82(ut1),
        erfa.rotation.gst00a(ut1, ut1),
        erfa.rotation.gst00b(ut1),
        erfa.rotation.gst06a(ut1, ut1),
        erfa.rotation.gst94(ut1),
        erfa.rotation.gst06(ut1, ut1, &erfa.Mat3{
            .{ 0.9999989440476103608, -0.1332881761240011518e-2, -0.5790767434730085097e-3 },
            .{ 0.1332858254308954453e-2, 0.9999991109044505944, -0.4097782710401555759e-4 },
            .{ 0.5791308472168153320e-3, 0.4020595661593994396e-4, 0.9999998314954572365 },
        }),
    };
    for (angles) |angle| try expect(angle >= 0.0 and angle < two_pi);

    const epoch = erfa.Date2{ .part_a = 2400000.5, .part_b = 53736.0 };
    try expectNear(-0.8834193235367965479e-5, erfa.rotation.ee00(epoch, 0.4090789763356509900, -0.9630909107115582393e-5), 1e-18);
    try expectNear(-0.8834192459222588227e-5, erfa.rotation.ee00a(epoch), 1e-18);
    try expectNear(-0.8835700060003032831e-5, erfa.rotation.ee00b(epoch), 1e-18);
    try expectNear(-0.8834195072043790156e-5, erfa.rotation.ee06a(epoch), 1e-15);
    try expectNear(0.2046085004885125264e-8, erfa.rotation.eect00(epoch), 1e-20);

    const site = erfa.Observatory{
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
    const date = erfa.Date2{ .part_a = 2456384.5, .part_b = 0.969254051 };
    const bad_date = erfa.Date2{ .part_a = -1e10, .part_b = 0.0 };

    const astrom = erfa.rotation.apco13(date, site);
    try expect(astrom.status.isOk());
    try expectNear(2.617608909189664000, (astrom.astrom orelse return error.MissingOutput).eral, 1e-12);
    try expectNear(-0.003020548354802412839, astrom.equation_of_origins orelse return error.MissingOutput, 1e-14);
    try expect(erfa.rotation.apco13(bad_date, site).astrom == null);

    const io = erfa.rotation.apio13(date, site);
    try expect(io.status.isOk());
    try expectNear(0.3299123514971474711, (io.astrom orelse return error.MissingOutput).cphi, 1e-12);
    try expect(erfa.rotation.apio13(bad_date, site).astrom == null);

    const icrs = erfa.ObservedSpherical{ .first = 2.71, .second = 0.174 };
    const motion = erfa.ObservedSpherical{ .first = 1e-5, .second = 5e-6 };

    const place = erfa.rotation.atco13(icrs, motion, 0.1, 55.0, date, site);
    try expect(place.status.isOk());
    try expectNear(2.710260453504961012, (place.place orelse return error.MissingOutput).right_ascension, 1e-12);
    try expect(place.equation_of_origins != null);
    try expect(erfa.rotation.atco13(icrs, motion, 0.1, 55.0, bad_date, site).place == null);

    const observed_place = erfa.rotation.atio13(date, site, .{ .first = 2.710121572969038991, .second = 0.1729371367218230438 });
    try expect(observed_place.status.isOk());
    try expectNear(1.407758704513549991, (observed_place.place orelse return error.MissingOutput).zenith_distance, 1e-12);
    try expect(erfa.rotation.atio13(bad_date, site, icrs).place == null);

    const kinds = [_]erfa.ObservationType{ .right_ascension, .hour_angle, .azimuth };
    const observed = [_]erfa.ObservedSpherical{
        .{ .first = 2.710085107986886201, .second = 0.1717653435758265198 },
        .{ .first = -0.09247619879782006106, .second = 0.1717653435758265198 },
        .{ .first = 0.09233952224794989993, .second = 1.407758704513722461 },
    };
    for (kinds, observed) |kind, angles_in| {
        try expect(erfa.rotation.atoc13(kind, angles_in, date, site).icrs != null);
        try expect(erfa.rotation.atoi13(kind, angles_in, date, site).cirs != null);
        try expect(erfa.rotation.atoc13(kind, angles_in, bad_date, site).icrs == null);
        try expect(erfa.rotation.atoi13(kind, angles_in, bad_date, site).cirs == null);
    }
}

fn exerciseGeodetic() Failure!void {
    for ([_]erfa.Ellipsoid{ .wgs84, .grs80, .wgs72 }) |ellipsoid| {
        const form = erfa.geodetic.eform(ellipsoid);
        try expect(form.status.isOk());
        try expect(form.equatorial_radius > 6.3e6);
        try expect(form.flattening > 0.003 and form.flattening < 0.004);
    }
    try expectNear(6378137.0, erfa.geodetic.eform(.wgs84).equatorial_radius, 1e-10);

    const cartesian = erfa.Vec3{ 2e6, 3e6, 5.244e6 };
    for ([_]erfa.Ellipsoid{ .wgs84, .grs80, .wgs72 }) |ellipsoid| {
        const geodetic = erfa.geodetic.gc2gd(ellipsoid, &cartesian);
        try expect(geodetic.status.isOk());
        try expect(geodetic.geodetic.latitude > 0.9 and geodetic.geodetic.latitude < 1.0);
        try expect(geodetic.geodetic.height > 0.0);
    }

    // The general form reports an illegal ellipsoid by leaving output absent.
    const general = erfa.geodetic.gc2gde(6378136.0, 0.0033528, &cartesian);
    try expectNear(0.9827937232473290680, (general.geodetic orelse return error.MissingOutput).longitude, 1e-14);
    try expect(erfa.geodetic.gc2gde(6378136.0, 1.5, &cartesian).geodetic == null);
    try expect(erfa.geodetic.gc2gde(0.0, 0.0033528, &cartesian).geodetic == null);

    const position = erfa.Geodetic{ .longitude = 3.1, .latitude = -0.5, .height = 2500.0 };
    for ([_]erfa.Ellipsoid{ .wgs84, .grs80, .wgs72 }) |ellipsoid| {
        try expect(erfa.geodetic.gd2gc(ellipsoid, position).status.isOk());
    }
    try expect(erfa.geodetic.gd2gce(6378136.0, 0.0033528, position).cartesian != null);
    // `gd2gce` accepts out-of-range flattening; only its divisor guard can fail.
    const outside_range = erfa.geodetic.gd2gce(6378136.0, 2.0, position);
    try expect(outside_range.status.isOk());
    try expect((outside_range.cartesian orelse return error.MissingOutput)[0] != 0.0);
}

fn exercisePrecession() Failure!void {
    const epoch = erfa.Date2{ .part_a = 2400000.5, .part_b = 53736.0 };
    const other = erfa.Date2{ .part_a = 2400000.5, .part_b = 50123.9999 };

    // Obliquity stays within 23.4-23.5 degrees; equation-of-date angles are smaller.
    const angle_bounds = [_]struct { value: f64, low: f64, high: f64 }{
        .{ .value = erfa.precession.obl06(.{ .part_a = 2400000.5, .part_b = 54388.0 }), .low = 23.4, .high = 23.5 },
        .{ .value = erfa.precession.obl80(.{ .part_a = 2400000.5, .part_b = 54388.0 }), .low = 23.4, .high = 23.5 },
        .{ .value = erfa.precession.eo06a(epoch), .low = -0.1, .high = 0.1 },
        .{ .value = erfa.precession.eqeq94(.{ .part_a = 2400000.5, .part_b = 41234.0 }), .low = -0.1, .high = 0.1 },
    };
    for (angle_bounds) |entry| {
        const in_degrees = entry.value * 57.29577951308232087679815;
        try expect(in_degrees > entry.low and in_degrees < entry.high);
    }

    const bpn = erfa.Mat3{
        .{ 0.9999989440476103608, -0.1332881761240011518e-2, -0.5790767434730085097e-3 },
        .{ 0.1332858254308954453e-2, 0.9999991109044505944, -0.4097782710401555759e-4 },
        .{ 0.5791308472168153320e-3, 0.4020595661593994396e-4, 0.9999998314954572365 },
    };
    try expectNear(-0.1332882715130744606e-2, erfa.precession.eors(&bpn, -0.1220040848472271978e-7), 1e-14);

    const gamma_bar = -0.2243387670997992368e-5;
    const phi_bar = 0.4091014602391312982;
    const psi = -0.9501954178013015092e-3;
    const epsilon = 0.4091014316587367472;
    const fw_matrix = erfa.precession.fw2m(gamma_bar, phi_bar, psi, epsilon);
    try expectOrthonormal(fw_matrix);
    const cip = erfa.precession.fw2xy(gamma_bar, phi_bar, psi, epsilon);
    try expectNear(fw_matrix[2][0], cip.x, 1e-14);
    try expectNear(fw_matrix[2][1], cip.y, 1e-14);

    const angles = erfa.precession.prec76(
        .{ .part_a = 2400000.5, .part_b = 33282.0 },
        .{ .part_a = 2400000.5, .part_b = 51544.0 },
    );
    try expect(angles.zeta > 0.0 and angles.z > 0.0 and angles.theta > 0.0);

    for ([_]erfa.Nutation{
        erfa.precession.nut00a(epoch),
        erfa.precession.nut00b(epoch),
        erfa.precession.nut06a(epoch),
        erfa.precession.nut80(epoch),
    }) |nutation| {
        try expect(std.math.isFinite(nutation.dpsi) and std.math.isFinite(nutation.deps));
    }

    for ([_]erfa.Mat3{
        erfa.precession.num00a(epoch),
        erfa.precession.num00b(epoch),
        erfa.precession.num06a(epoch),
        erfa.precession.nutm80(epoch),
    }) |matrix| try expectOrthonormal(matrix);

    const supplied_dpsi = -0.9632552291149335877e-5;
    const supplied_deps = 0.4063197106621141414e-4;
    // Supplied nutation angles are inputs, not outputs.
    const pn00_result = erfa.precession.pn00(epoch, supplied_dpsi, supplied_deps);
    try expectOrthonormal(pn00_result.rb);
    try expectOrthonormal(pn00_result.rp);
    try expectOrthonormal(pn00_result.rbp);
    try expectOrthonormal(pn00_result.rn);
    try expectOrthonormal(pn00_result.rbpn);

    const pn06_result = erfa.precession.pn06(epoch, supplied_dpsi, supplied_deps);
    try expectOrthonormal(pn06_result.rbpn);
    try expect(std.math.isFinite(pn06_result.epsa));

    for ([_]erfa.PrecessionNutation{
        erfa.precession.pn00a(epoch),
        erfa.precession.pn00b(epoch),
        erfa.precession.pn06a(epoch),
    }) |result| {
        try expectOrthonormal(result.rb);
        try expectOrthonormal(result.rp);
        try expectOrthonormal(result.rbp);
        try expectOrthonormal(result.rn);
        try expectOrthonormal(result.rbpn);
    }

    for ([_]erfa.Mat3{
        erfa.precession.pnm00a(other),
        erfa.precession.pnm00b(other),
        erfa.precession.pnm06a(other),
        erfa.precession.pnm80(other),
        erfa.precession.pmat00(other),
        erfa.precession.pmat06(other),
        erfa.precession.pmat76(other),
        erfa.precession.pom00(2.55060238e-7, 1.860359247e-6, -0.1367174580728891460e-10),
        erfa.precession.ltecm(-3000.0),
        erfa.precession.ltp(1666.666),
        erfa.precession.ltpb(1666.666),
    }) |matrix| try expectOrthonormal(matrix);

    const ecliptic = erfa.precession.lteqec(-1500.0, .{ .right_ascension = 1.234, .declination = 0.987 });
    try expect(ecliptic.longitude > 0.0 and ecliptic.latitude > 0.0);
    const equatorial = erfa.precession.lteceq(2500.0, .{ .longitude = 1.5, .latitude = 0.6 });
    try expect(equatorial.right_ascension > 0.0 and equatorial.declination > 0.0);

    // These functions return complete unit vectors.
    const to_ecliptic = erfa.precession.ltpecl(-1500.0);
    try expectNear(1.0, @sqrt(to_ecliptic[0] * to_ecliptic[0] +
        to_ecliptic[1] * to_ecliptic[1] +
        to_ecliptic[2] * to_ecliptic[2]), 1e-14);
    const to_equatorial = erfa.precession.ltpequ(-2500.0);
    try expectNear(1.0, @sqrt(to_equatorial[0] * to_equatorial[0] +
        to_equatorial[1] * to_equatorial[1] +
        to_equatorial[2] * to_equatorial[2]), 1e-14);
}

fn exerciseEphemerides() Failure!void {
    const date = erfa.Date2{ .part_a = 2400000.5, .part_b = 53411.52501161 };
    const earth = erfa.ephemeris.epv00(date);
    try expect(earth.status.isOk());
    for ([_]f64{
        earth.heliocentric.position[0],
        earth.heliocentric.position[1],
        earth.heliocentric.position[2],
        earth.heliocentric.velocity[0],
        earth.barycentric.position[0],
        earth.barycentric.position[2],
    }) |value| try expect(std.math.isFinite(value));
    try expect(erfa.ephemeris.epv00(.{ .part_a = 6200000.0, .part_b = 0.0 }).status.isWarning());

    for ([_]i32{ 0, 9 }) |planet| {
        const rejected = erfa.ephemeris.plan94(.{ .part_a = 2400000.5, .part_b = 1e6 }, planet);
        try expect(rejected.status.isError());
        for (rejected.pv.position) |value| try expect(value == 0.0);
        for (rejected.pv.velocity) |value| try expect(value == 0.0);
    }
    try expect(erfa.ephemeris.plan94(.{ .part_a = 2400000.5, .part_b = -320000.0 }, 3).status.isWarning());
    try expect(erfa.ephemeris.plan94(.{ .part_a = 2400000.5, .part_b = 43999.9 }, 1).status.isOk());

    const moon = erfa.ephemeris.moon98(.{ .part_a = 2400000.5, .part_b = 43999.9 });
    for ([_]f64{ moon.position[0], moon.position[1], moon.position[2], moon.velocity[2] }) |value| {
        try expect(std.math.isFinite(value));
    }
}

fn exerciseVectors() Failure!void {
    const p = erfa.Vec3{ 0.3, 1.2, -2.5 };
    const parts = erfa.vectors.pn(&p);
    try expectNear(2.789265136196270604, parts.modulus, 1e-12);
    try expectNear(parts.modulus, erfa.vectors.pm(&p), 1e-15);
    try expectNear(1.0, @sqrt(parts.unit[0] * parts.unit[0] +
        parts.unit[1] * parts.unit[1] +
        parts.unit[2] * parts.unit[2]), 1e-14);

    const zero = erfa.vectors.pn(&erfa.Vec3{ 0.0, 0.0, 0.0 });
    try expect(zero.modulus == 0.0);

    const deflected = erfa.vectors.ld(
        0.00028574,
        &erfa.Vec3{ -0.763276255, -0.608633767, -0.216735543 },
        &erfa.Vec3{ -0.763276255, -0.608633767, -0.216735543 },
        &erfa.Vec3{ 0.76700421, 0.605629598, 0.211937094 },
        8.91276983,
        3e-10,
    );
    for (deflected) |value| try expect(std.math.isFinite(value));
}

/// Exercises the rest of the facade: vector algebra, matrices, coordinate frames,
/// catalogue transforms, atmospheric models and fundamental arguments.
/// Checks invariants so every wrapper body is instantiated without duplicating `tests.zig`.
fn exerciseExtendedSurface() Failure!void {
    const date = erfa.Date2{ .part_a = 2400000.5, .part_b = 53736.0 };

    // The normalizers use different ranges; `anpm(pi)` returns `-pi`.
    try expectNear(2.0 * std.math.pi - 1.0, erfa.angles.anp(-1.0), 1e-15);
    try expectNear(-1.0, erfa.angles.anpm(-1.0), 1e-15);
    try expectNear(-std.math.pi, erfa.angles.anpm(std.math.pi), 1e-15);
    // A half-turn is 180 degrees or 12 hours; the leading fields are not wrapped.
    const degrees = erfa.angles.a2af(3, std.math.pi);
    try expect(degrees.sign == '+' and degrees.degrees == 180);
    try expect(degrees.arcminutes == 0 and degrees.arcseconds == 0 and degrees.fraction == 0);
    const hours = erfa.angles.a2tf(3, std.math.pi);
    try expect(hours.sign == '+' and hours.hours == 12);
    try expect(hours.minutes == 0 and hours.seconds == 0 and hours.fraction == 0);

    // Rotations are orthonormal; rotation-vector sign is unambiguous below pi.
    const quarter = std.math.pi / 4.0;
    const rotations = [_]erfa.Mat3{
        erfa.matrices.rotateX(quarter),
        erfa.matrices.rotateY(quarter),
        erfa.matrices.rotateZ(quarter),
        erfa.matrices.identity(),
    };
    for (rotations) |rotation| try expectOrthonormal(rotation);
    for (erfa.matrices.zero()) |row| {
        for (row) |value| try expect(value == 0.0);
    }
    for (erfa.matrices.zeroVector()) |value| try expect(value == 0.0);
    try expect(erfa.matrices.zeroPv().velocity[0] == 0.0);
    for (&rotations) |*rotation| {
        const transposed = erfa.matrices.transpose(rotation);
        const round_tripped = erfa.matrices.multiply(rotation, &transposed);
        for (0..3) |row| {
            for (0..3) |column| {
                try expectNear(if (row == column) 1.0 else 0.0, round_tripped[row][column], 1e-15);
            }
        }
        const axis_angle = erfa.matrices.toRotationVector(rotation);
        try expectOrthonormal(erfa.matrices.fromRotationVector(&axis_angle));
    }
    const identity = erfa.matrices.identity();
    try expect(erfa.matrices.toRotationVector(&identity)[0] == 0.0);

    const probe = erfa.Vec3{ 0.3, -1.2, 2.5 };
    const turned = erfa.matrices.apply(&rotations[0], &probe);
    for (probe, erfa.matrices.applyTransposed(&rotations[0], &turned)) |want, got| {
        try expectNear(want, got, 1e-15);
    }
    const probe_pv = erfa.Pv{ .position = probe, .velocity = .{ -0.1, 0.2, -0.3 } };
    const turned_pv = erfa.matrices.applyPv(&rotations[1], probe_pv);
    for (probe_pv.velocity, erfa.matrices.applyTransposedPv(&rotations[1], turned_pv).velocity) |want, got| {
        try expectNear(want, got, 1e-15);
    }
    try expect(erfa.matrices.copyVector(&probe)[1] == probe[1]);
    try expect(erfa.matrices.copyMatrix(&rotations[0])[2][1] == rotations[0][2][1]);
    try expect(erfa.matrices.copyPv(probe_pv).position[2] == probe_pv.position[2]);
    try expect(erfa.matrices.positionToPv(&probe).velocity[0] == 0.0);
    for (probe, erfa.matrices.pvToPosition(probe_pv)) |want, got| try expectNear(want, got, 0.0);

    // Cartesian conversion preserves the fourth-quadrant angle.
    const unit = erfa.spherical.toCartesian(0.3, -0.2);
    const angles_back = erfa.spherical.fromCartesian(&unit);
    try expectNear(0.3, angles_back.theta, 1e-15);
    try expectNear(-0.2, angles_back.phi, 1e-15);
    const point = erfa.spherical.cartesianToSpherical(&probe);
    try expectNear(erfa.vectors.pm(&probe), point.radius, 1e-15);
    for (erfa.spherical.toCartesianWithRadius(0.3, -0.2, 5.0)) |value| {
        try expect(std.math.isFinite(value));
    }
    const rates = erfa.spherical.pvToSpherical(probe_pv);
    const rebuilt_pv = erfa.spherical.toPv(
        rates.theta,
        rates.phi,
        rates.radius,
        rates.theta_rate,
        rates.phi_rate,
        rates.radius_rate,
    );
    for (probe_pv.position, rebuilt_pv.position) |want, got| try expectNear(want, got, 1e-12);

    // Horizon conversions invert for non-polar directions.
    const horizontal = erfa.horizon.azimuthElevationToHorizontal(1.1, 0.4, 0.8);
    const altitude = erfa.horizon.horizontalToAzimuthElevation(horizontal.first, horizontal.second, 0.8);
    try expectNear(1.1, altitude.first, 1e-12);
    try expectNear(0.4, altitude.second, 1e-12);
    try expect(erfa.horizon.horizontalToParallax(horizontal.first, horizontal.second, 0.8) != 0.0);

    // The ecliptic matrix matches its coordinate conversion.
    const ecliptic_matrix = erfa.ecliptic.matrix(date);
    try expectOrthonormal(ecliptic_matrix);
    const equatorial = erfa.ecliptic.fromEcliptic(date, .{ .longitude = 1.0, .latitude = 0.2 });
    const back_to_ecliptic = erfa.ecliptic.toEcliptic(date, equatorial);
    try expectNear(1.0, back_to_ecliptic.longitude, 1e-12);
    try expectNear(0.2, back_to_ecliptic.latitude, 1e-12);
    const ecliptic_direction = erfa.spherical.toCartesian(
        equatorial.right_ascension,
        equatorial.declination,
    );
    const rotated = erfa.matrices.apply(&ecliptic_matrix, &ecliptic_direction);
    try expectNear(1.0, erfa.spherical.fromCartesian(&rotated).theta, 1e-12);

    // The fixed galactic rotation inverts.
    const galactic = erfa.galactic.toIcrs(1.0, 0.2);
    const icrs = erfa.galactic.fromIcrs(galactic.right_ascension, galactic.declination);
    try expectNear(1.0, icrs.longitude, 1e-12);
    try expectNear(0.2, icrs.latitude, 1e-12);

    // Forward projection returns two directions; inverse projection is a separate operation.
    // Check both solutions away from the plane edge and none on it.
    const reference = erfa.StandardCoordinates{ .a = 0.0, .b = 0.0 };
    const projected = erfa.gnomonic.fromStandardCoordinates(0.01, 0.02, reference);
    try expect(projected.status.value > 0);
    try expect(projected.first != null and projected.second != null);
    try expect(erfa.gnomonic.fromStandardCoordinates(
        0.01,
        0.02,
        .{ .a = 0.0, .b = std.math.pi / 2.0 },
    ).first == null);

    const forward = erfa.gnomonic.toStandardCoordinates(0.01, 0.02, reference);
    const inverted = erfa.gnomonic.fromStandardCoordinatesInverse(forward, reference);
    try expect(inverted.status.isOk());
    try expectNear(0.01, inverted.coordinates.a, 1e-6);
    try expectNear(0.02, inverted.coordinates.b, 1e-6);

    const axis = erfa.Vec3{ 1.0, 0.0, 0.0 };
    const gnomonic_vector = erfa.gnomonic.toVector(0.01, 0.02, &axis);
    const vector_solution = erfa.gnomonic.fromVector(0.01, 0.02, &axis);
    try expect(vector_solution.first != null and vector_solution.second != null);
    const vector_inverse = erfa.gnomonic.fromVectorInverse(&gnomonic_vector, &axis);
    try expect(vector_inverse.status.isOk());
    try expectNear(0.01, vector_inverse.coordinates.a, 1e-6);
    try expectNear(0.02, vector_inverse.coordinates.b, 1e-6);

    // Refraction A is positive and B negative under upstream's formula at these conditions.
    const refraction = erfa.atmosphere.refractionConstants(1010.0, 10.0, 0.5, 0.55);
    try expect(refraction.a > 0.0 and refraction.b < 0.0);

    // Earth-observer TDB-TT is a finite millisecond-scale estimate.
    const tdb_minus_tt = erfa.timescale.dtdb(date, 0.5, 1.1, 4500.0, 1000.0);
    try expect(std.math.isFinite(tdb_minus_tt));
    try expect(@abs(tdb_minus_tt) < 1.0);

    // `datini` installs `builtin` only when no positive-count table is active.
    var replacement_table = [_]erfa.LeapSecond{.{ .iyear = 2000, .month = 1, .delat = 12.0 }};
    erfa.leap.setLeapSeconds(null);
    const installed = erfa.leap.datini(replacement_table[0..]);
    try expect(installed.status.value == 1);
    try expect((installed.entries orelse return error.MissingOutput)[0].delat == 12.0);
    const ignored = erfa.leap.datini(null);
    try expect(ignored.status.value == 1);
    try expect((ignored.entries orelse return error.MissingOutput)[0].delat == 12.0);
    // Restore the built-in table before checking TAI-UTC.
    erfa.leap.setLeapSeconds(null);
    try expectNear(37.0, erfa.timescale.dat(2020, 6, 1, 0.0).delta_at, 0.0);

    // Check vector identities rather than duplicating computed expected values.
    const other = erfa.Vec3{ -0.7, 0.4, 1.1 };
    try expectNear(
        probe[0] * other[0] + probe[1] * other[1] + probe[2] * other[2],
        erfa.vectors.pdp(&probe, &other),
        1e-15,
    );
    for (probe, other, erfa.vectors.pmp(&probe, &other)) |a, b, got| {
        try expectNear(a - b, got, 1e-15);
    }
    for (probe, other, erfa.vectors.ppp(&probe, &other)) |a, b, got| {
        try expectNear(a + b, got, 1e-15);
    }
    for (erfa.vectors.ppsp(&probe, 2.0, &other)) |got| try expect(std.math.isFinite(got));
    const cross = erfa.vectors.pxp(&probe, &other);
    // The cross product is perpendicular to both operands.
    try expectNear(0.0, erfa.vectors.pdp(&cross, &probe), 1e-15);
    try expectNear(0.0, erfa.vectors.pdp(&cross, &other), 1e-15);
    for (probe, erfa.vectors.sxp(3.0, &probe)) |want, got| try expectNear(3.0 * want, got, 1e-15);
    try expect(erfa.vectors.sxpv(2.0, probe_pv).velocity[1] == 2.0 * probe_pv.velocity[1]);
    // Different exact scales and unrelated vectors distinguish all six outputs.
    const scaled_separately = erfa.vectors.s2xpv(3.0, -0.5, probe_pv);
    for (probe_pv.position, scaled_separately.position) |want, got| {
        try expect(3.0 * want == got);
    }
    for (probe_pv.velocity, scaled_separately.velocity) |want, got| {
        try expect(-0.5 * want == got);
    }
    try expectNear(erfa.vectors.pm(&probe_pv.position), erfa.vectors.pvm(probe_pv).radius, 1e-15);
    for (probe_pv.position, probe_pv.velocity, erfa.vectors.pvu(0.5, probe_pv).position) |position, velocity, got| {
        try expectNear(position + 0.5 * velocity, got, 1e-14);
    }
    for (erfa.vectors.pvup(0.5, probe_pv)) |got| try expect(std.math.isFinite(got));
    try expectNear(
        erfa.vectors.pdp(&probe_pv.position, &probe_pv.position),
        erfa.vectors.pvdpv(probe_pv, probe_pv).position_position,
        1e-14,
    );
    try expect(erfa.vectors.pvmpv(probe_pv, probe_pv).position[0] == 0.0);
    try expect(erfa.vectors.pvppv(probe_pv, probe_pv).position[1] == 2.0 * probe_pv.position[1]);
    for (erfa.vectors.pvxpv(probe_pv, probe_pv).velocity) |component| {
        try expectNear(0.0, component, 1e-14);
    }
    const probe_angles = erfa.spherical.fromCartesian(&probe);
    const other_angles = erfa.spherical.fromCartesian(&other);
    try expectNear(
        erfa.vectors.pap(&probe, &other),
        erfa.vectors.pas(probe_angles.theta, probe_angles.phi, other_angles.theta, other_angles.phi),
        1e-12,
    );
    try expectNear(
        erfa.vectors.sepp(&probe, &other),
        erfa.vectors.seps(probe_angles.theta, probe_angles.phi, other_angles.theta, other_angles.phi),
        1e-12,
    );

    // `eraLdn` returns the input direction and its deflected result separately.
    const bodies = [_]erfa.LightDeflectingBody{
        .{ .bm = 0.00028574, .dl = 3e-10, .pv = .{ .{ 0.0, 0.0, 0.0 }, .{ 0.0, 0.0, 0.0 } } },
    };
    const line_of_sight = erfa.Vec3{ 0.3, 0.4, 0.5 };
    const deflection = erfa.vectors.ldn(&bodies, &erfa.Vec3{ 0.8, 0.5, 0.2 }, &line_of_sight);
    for (line_of_sight, deflection.in_place) |want, got| try expectNear(want, got, 0.0);
    try expect(std.math.isFinite(deflection.deflected[0]));
    for (erfa.vectors.ldsun(
        &erfa.Vec3{ -0.763276255, -0.608633767, -0.216735543 },
        &erfa.Vec3{ 0.76700421, 0.605629598, 0.211937094 },
        0.0089985,
    )) |value| try expect(std.math.isFinite(value));
    const aberrated = erfa.vectors.ab(
        &erfa.Vec3{ 0.3, 0.4, 0.5 },
        &erfa.Vec3{ 1e-5, -2e-5, 3e-5 },
        0.99980921395708788,
        0.9999999999999,
    );
    try expectNear(1.0, @sqrt(
        aberrated[0] * aberrated[0] + aberrated[1] * aberrated[1] + aberrated[2] * aberrated[2],
    ), 1e-12);
    for (erfa.vectors.pvtob(1.1, 0.8, 2500.0, 1e-7, -1e-7, 0.0, 0.3).position) |value| {
        try expect(std.math.isFinite(value));
    }

    // A star at ten parsecs is clear of the parallax floor and round-trips.
    const star = erfa.StarMotion{
        .right_ascension = 1.1,
        .declination = 0.4,
        .pm_ra = 1e-5,
        .pm_dec = -2e-5,
        .parallax = 0.1,
        .radial_velocity = -20.0,
    };
    const space_motion = erfa.vectors.starpv(star);
    try expect(!space_motion.status.isError());
    const recovered = (erfa.vectors.pvstar(space_motion.pv).star) orelse
        return error.MissingOutput;
    try expectNear(star.right_ascension, recovered.right_ascension, 1e-9);
    try expectNear(star.declination, recovered.declination, 1e-9);
    const later = erfa.Date2{ .part_a = 2400000.5, .part_b = 54135.0 };
    try expect((erfa.vectors.starpm(star, date, later).star) != null);
    try expect((erfa.vectors.pmsafe(star, date, later).star) != null);
    const pmpx = erfa.vectors.pmpx(
        .{ .first = star.right_ascension, .second = star.declination },
        .{ .first = star.pm_ra, .second = star.pm_dec },
        star.parallax,
        star.radial_velocity,
        25.0,
        &erfa.Vec3{ 0.8, 0.5, 0.2 },
    );
    try expectNear(1.0, @sqrt(
        pmpx[0] * pmpx[0] +
            pmpx[1] * pmpx[1] +
            pmpx[2] * pmpx[2],
    ), 1e-12);

    // Catalogue transforms must round-trip position and proper motion.
    const fk5 = erfa.StarMotion{
        .right_ascension = 1.1,
        .declination = 0.4,
        .pm_ra = 1e-5,
        .pm_dec = -2e-5,
        .parallax = 0.1,
        .radial_velocity = -20.0,
    };
    const hipparcos = erfa.starCatalogs.fk5ToHipparcos(fk5);
    const back_to_fk5 = erfa.starCatalogs.hipparcosToFk5(hipparcos);
    try expectNear(fk5.right_ascension, back_to_fk5.right_ascension, 1e-12);
    try expectNear(fk5.declination, back_to_fk5.declination, 1e-12);
    try expect(erfa.starCatalogs.fk4ToFk5(fk5).right_ascension != 0.0);
    try expect(erfa.starCatalogs.fk4ToFk5Position(
        fk5.right_ascension,
        fk5.declination,
        1950.0,
    ).right_ascension != 0.0);
    try expectNear(fk5.right_ascension, erfa.starCatalogs.fk5ToFk4(
        erfa.starCatalogs.fk4ToFk5(fk5),
    ).right_ascension, 1e-9);
    try expect(erfa.starCatalogs.fk5ToFk4Position(
        fk5.right_ascension,
        fk5.declination,
        1950.0,
    ).pm_ra != 0.0);
    try expectOrthonormal(erfa.starCatalogs.hipparcosConstants().rotation);
    const dated = erfa.starCatalogs.fk5ToHipparcosAtDate(fk5.right_ascension, fk5.declination, date);
    try expectNear(fk5.right_ascension, erfa.starCatalogs.hipparcosToFk5AtDate(
        dated.right_ascension,
        dated.declination,
        date,
    ).right_ascension, 1e-12);

    // Fundamental arguments are finite at J2000; accumulated precession is zero.
    const arguments = [_]f64{
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
        erfa.fundamentalArgs.accumulatedPrecession(0.0),
        erfa.fundamentalArgs.saturnLongitude(0.0),
        erfa.fundamentalArgs.uranusLongitude(0.0),
        erfa.fundamentalArgs.venusLongitude(0.0),
    };
    for (arguments) |value| try expect(std.math.isFinite(value));
    try expectNear(0.0, erfa.fundamentalArgs.accumulatedPrecession(0.0), 1e-15);
}

/// Shared library exporting the four ERFA headers' entry points.
const provider_variable = "ERFA_TEST_PROVIDER";

pub fn main(init: std.process.Init) void {
    // Load the provider before calls; the linked-build branch is comptime-elided.
    if (comptime erfa.runtime_loaded) {
        erfa.load(.{ .path = providerRequest(init) }) catch |err| {
            std.debug.print("api_exercise: loading the provider failed: {t}\n", .{err});
            std.process.exit(1);
        };
        std.debug.print("api_exercise: loaded {s}\n", .{erfa.loadedSource().?.path});
    }
    exercise() catch |err| {
        std.debug.print("api_exercise failed: {s}\n", .{@errorName(err)});
        // The return trace identifies the failed check.
        if (@errorReturnTrace()) |trace| std.debug.dumpErrorReturnTrace(trace);
        std.process.exit(1);
    };
    std.debug.print("api_exercise: every public facade method was called\n", .{});
}

/// Select the runtime provider from `--provider <path>` or `ERFA_TEST_PROVIDER`; no implicit fallback.
fn providerRequest(init: std.process.Init) []const u8 {
    const args = init.minimal.args.toSlice(init.arena.allocator()) catch return noProvider();
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        if (std.mem.eql(u8, args[index], "--provider")) {
            if (index + 1 >= args.len) return noProvider();
            return args[index + 1];
        }
    }
    return init.environ_map.get(provider_variable) orelse return noProvider();
}

/// Report the missing provider configuration.
fn noProvider() []const u8 {
    std.debug.print(
        "api_exercise: this is a runtime-loading build. Pass --provider <path>, " ++
            "or export " ++ provider_variable ++ " with a shared object exporting " ++
            "the entry points of src/erfa.h, src/erfam.h, src/erfaextra.h and " ++
            "src/erfadatextra.h. Nothing is loaded by default and no other file " ++
            "is tried.\n",
        .{},
    );
    std.process.exit(1);
}
