const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(
        std.lang.LinkMode,
        "linkage",
        "Which delivery of erfa to build against: the static archive (the " ++
            "library's own default) or the shared object. Forwarded to the " ++
            "library unchanged.",
    ) orelse .static;

    // Pass runtime mode through unchanged to the dependency.
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

    // The dependency declares libc; this consumer does not add it.
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("erfa", dep.module("erfa"));

    const exe = b.addExecutable(.{
        // Use LLVM for wide ERFA C signatures.
        .use_llvm = true,
        .name = "erfa-consumer",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    // Ensure each run executes instead of reusing the run cache.
    run_exe.has_side_effects = true;
    // Forward `zig build run` arguments to the program.
    run_exe.addPassthruArgs();
    const run_step = b.step("run", "Build and run the consumer program");
    run_step.dependOn(&run_exe.step);
}
