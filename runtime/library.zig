// SPDX-License-Identifier: BSD-3-Clause

const rt = @import("rt");

/// Synchronization callbacks required by the loader.
pub const Sync = struct {
    extern fn erfa_rt_lock() void;
    extern fn erfa_rt_unlock() void;
    extern fn erfa_rt_wait() void;
    extern fn erfa_rt_broadcast() void;
    // C declares this as `unsigned long long`.
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

// Bounds for years in provider leap-second records.
const table_year_low: i32 = 1900;
const table_year_high: i32 = 2200;

/// Binds the loader to ERFA's dispatch and provider checks.
pub fn Config(comptime dispatch: type) type {
    return struct {
        /// Used in pre-load diagnostics.
        pub const library_name = "erfa";

        /// The generated dispatch table.
        pub const table = dispatch.Table;
        pub const symbols = dispatch.symbols;
        pub const optional_symbols = dispatch.optional_symbols;

        /// ERFA's namespaced synchronization binding.
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

        /// Checks the provider and returns a refusal message on mismatch.
        pub fn validate(dst: *const table) ?[]const u8 {
            if (dst.eraSofaVersion()[0] == 0) {
                return "eraSofaVersion() answered with an empty string, so this " ++
                    "provider is not the library this header describes";
            }
            return leapTableShape(dst);
        }

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
