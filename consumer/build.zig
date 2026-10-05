//! A package that consumes `erfa` from outside.
//!
//! This exists to prove one thing: that a dependent needs only
//! `dep.module("erfa")` and gets a working, correctly linked library against
//! the four headers upstream installs. If the facade module stopped carrying
//! its C artefact, or the translated header stopped matching the C sources,
//! this would stop building or stop producing the answers below, and nothing
//! inside the library would notice.
//!
//! Run it with `zig build run`. It exits non-zero if any value disagrees with
//! the answer stated in the source next to it, so it is a check and not a
//! demo. Every expectation it compares against is a published SOFA/ERFA value
//! read out of the library's own documentation comments, not a value this
//! program computed for itself; see `src/main.zig` for the provenance of each.
//!
//! Two options are passed through, and both are the library's own. `-Dlinkage`
//! selects `lib erfa.a` (the default) or the shared object; `-Druntime` selects
//! whether the module resolves its native entry points through an explicit
//! `load` instead of through a link line. The same values are handed to
//! `b.dependency("erfa", ...)`, so the consumer is built against exactly the
//! configuration that was asked for. Nothing here interprets either one: a
//! value the library does not recognise, or a combination it cannot deliver,
//! is the library's error to report, not something this build translates into
//! something else.
//!
//! Under `-Druntime` the library is still built and installed by the dependency,
//! and this program names the provider it dispatches to -- see
//! `providerRequest` in `src/main.zig`, which is where that path comes from.
//! That path is named on the run's own command line, so
//! `zig build run -Druntime=true -- --provider <path>` reaches it: the run step
//! forwards `b.args` to the program rather than leaving the two to disagree.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(
        std.builtin.LinkMode,
        "linkage",
        "Which delivery of erfa to build against: the static archive (the " ++
            "library's own default) or the shared object. Forwarded to the " ++
            "library unchanged.",
    ) orelse .static;

    // Forwarded rather than interpreted, for the same reason as `-Dlinkage`. It
    // is what makes this package a consumer of the provider route as well as of
    // the linked one: with it set, the dependency builds no module that links
    // the archive, and `src/main.zig` -- which asks `erfa.runtime_loaded` at
    // comptime -- calls `erfa.load` with the provider path it is given instead.
    const runtime = b.option(
        bool,
        "runtime",
        "Build against erfa's provider route: the module resolves its native " ++
            "entry points through an explicit load instead of linking them. " ++
            "The library is still built and installed; this program names the " ++
            "provider. Forwarded to the library unchanged.",
    ) orelse false;

    const dep = b.dependency("erfa", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .runtime = runtime,
    });

    // No `link_libc` here on purpose. The C requirement belongs to the library
    // module, which carries it along with libm; a dependent states its own, and
    // this program needs nothing beyond what the library already brings.
    // Adding it here would hide a library that forgot to declare it.
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("erfa", dep.module("erfa"));

    const exe = b.addExecutable(.{
        // Wide ERFA C signatures require LLVM with Zig 0.16.
        .use_llvm = true,
        .name = "erfa-consumer",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    // Without this, a run whose inputs did not change is served from the run
    // cache and the program never executes, which would let a second
    // `zig build run` report success without observing anything.
    run_exe.has_side_effects = true;
    // `src/main.zig` documents `--provider <path>` on the command line under
    // `-Druntime`, and `b.args` is where those arguments arrive. Without this
    // line `zig build run -- --provider <path>` drops the flag, the program
    // falls through to `ERFA_TEST_PROVIDER`, finds none, and exits telling the
    // caller to pass the flag they just passed.
    if (b.args) |args| run_exe.addArgs(args);
    const run_step = b.step("run", "Build and run the consumer program");
    run_step.dependOn(&run_exe.step);
}
