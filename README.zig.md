# Zig facade API

## Facade namespaces

The raw translated C declarations and macros are available through `c`, including `c.eraASTROM` and `c.eraLEAPSECOND`.

| Namespace | Operations |
|---|---|
| `leap` | Read, replace, or reset the leap-second table; initialize a table. |
| `calendar` | Calendar dates, Julian dates, time formats, and Besselian/Julian epochs. |
| `timescale` | UTC, TAI, UT1, TT, TCG, TCB, and TDB conversions. |
| `rotation` | Earth rotation, sidereal time, equations of the equinoxes, and observed-place transformations. |
| `geodetic` | Ellipsoids and geocentric/geodetic conversions. |
| `precession` | Precession, nutation, and long-term ecliptic operations. |
| `ephemeris` | Earth, Moon, and planetary positions and velocities. |
| `vectors` | Vector and position/velocity operations, astrometry, and star motion. |
| `matrices` | 3×3 matrices, rotations, and vector/Pv transforms. |
| `angles` | Angle normalization and formatting. |
| `spherical` | Spherical, Cartesian, and Pv coordinate transforms. |
| `horizon` | Horizon and equatorial coordinate transforms. |
| `ecliptic` | Ecliptic and ICRS coordinate transforms. |
| `galactic` | Galactic and ICRS coordinate transforms. |
| `gnomonic` | Gnomonic projection and inverse transforms. |
| `atmosphere` | Atmospheric refraction constants. |
| `starCatalogs` | FK4, FK5, and Hipparcos transformations. |
| `fundamentalArgs` | IAU 2003 fundamental arguments. |

Method signatures and per-routine units and status ladders are documented beside the declarations in `zig/root.zig`.

## Shared types and results

- `Date2 { part_a, part_b }` preserves the two-part date. Its value is the sum; `sum()` returns that value. Do not normalize the split. `TimeScale` is the enum `tai`, `tt`, `ut1`, `utc`, `tcg`, `tcb`, or `tdb`.
- `Status.value` is the upstream signed `i32`: zero is success, a positive value is a warning, and a negative value is an error. `isOk()`, `isWarning()`, and `isError()` test those cases. The facade does not convert statuses to booleans or Zig errors.
- Result records keep outputs beside their status. An optional output is `null` only when upstream leaves it unwritten; upstream's defined sentinels remain values. `gnomonic.fromStandardCoordinates` and `gnomonic.fromVector` return solution counts in `status` (`0`, `1`, or `2`), not SOFA statuses. `leap.getLeapSeconds` returns an entry count or `-1`.
- `Vec3` is `[3]f64`, `Mat3` is `[3][3]f64`, and `Pv` contains `position` and `velocity`. `LeapSecond` and `LightDeflectingBody` alias the C records. `Astrom` and `ObservedAstrom` expose the fields their respective ERFA routines write.

## Leap-second table ownership

`leap.getLeapSeconds()` returns a borrowed slice of the active table. `leap.setLeapSeconds(entries)` retains the supplied storage without copying it; keep that storage alive and unchanged until replacement or reset. Pass `null` to reset to the built-in table. The storage follows upstream's `ERFA_THREAD_LOCAL` selection, which may be thread-local or process-global.

## Runtime loader API

`runtime_loaded` identifies the selected module shape at comptime. `LoadSource` accepts `.path` for an explicit file or `.system` for a platform-loader name. In a runtime-loaded build, call `load(source)` before any ERFA routine. It returns `LoadError!void`, keeps the provider handle for the process lifetime, and does not fall back to another source. `loadedSource()` returns the successful request or `null`. Calling `load` in a linked build panics. There is no unload or reset.
