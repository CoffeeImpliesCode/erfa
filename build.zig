const std = @import("std");

/// Both runtime paths must share one core module for `LoadSource` and `LoadError`.
const runtime_graph = @import("runtime/graph.zig");

const lib_name = "erfa";

const package_version = "2.0.1";

const sofa_version = "20231011";

/// Upstream ABI version: `configure.ac:20` records libtool `current:revision:age` as 9:1:8.
const abi_version: std.SemanticVersion = .{ .major = 1, .minor = 8, .patch = 1 };

const core_sources = [_][]const u8{
    "src/a2af.c",         "src/a2tf.c",   "src/ab.c",     "src/ae2hd.c",  "src/af2a.c",   "src/anp.c",    "src/anpm.c",   "src/apcg13.c",
    "src/apcg.c",         "src/apci13.c", "src/apci.c",   "src/apco13.c", "src/apco.c",   "src/apcs13.c", "src/apcs.c",   "src/aper13.c",
    "src/aper.c",         "src/apio13.c", "src/apio.c",   "src/atcc13.c", "src/atccq.c",  "src/atci13.c", "src/atciq.c",  "src/atciqn.c",
    "src/atciqz.c",       "src/atco13.c", "src/atic13.c", "src/aticq.c",  "src/aticqn.c", "src/atio13.c", "src/atioq.c",  "src/atoc13.c",
    "src/atoi13.c",       "src/atoiq.c",  "src/bi00.c",   "src/bp00.c",   "src/bp06.c",   "src/bpn2xy.c", "src/c2i00a.c", "src/c2i00b.c",
    "src/c2i06a.c",       "src/c2ibpn.c", "src/c2ixy.c",  "src/c2ixys.c", "src/c2s.c",    "src/c2t00a.c", "src/c2t00b.c", "src/c2t06a.c",
    "src/c2tcio.c",       "src/c2teqx.c", "src/c2tpe.c",  "src/c2txy.c",  "src/cal2jd.c", "src/cp.c",     "src/cpv.c",    "src/cr.c",
    "src/d2dtf.c",        "src/d2tf.c",   "src/dat.c",    "src/dtdb.c",   "src/dtf2d.c",  "src/eceq06.c", "src/ee00a.c",  "src/ee00.c",
    "src/eect00.c",       "src/eo06a.c",  "src/epb2jd.c", "src/epj2jd.c", "src/epv00.c",  "src/eqeq94.c", "src/ecm06.c",  "src/ee00b.c",
    "src/ee06a.c",        "src/eform.c",  "src/eors.c",   "src/epb.c",    "src/epj.c",    "src/eqec06.c", "src/era00.c",  "src/fad03.c",
    "src/fae03.c",        "src/faf03.c",  "src/faju03.c", "src/fal03.c",  "src/falp03.c", "src/fama03.c", "src/fame03.c", "src/fane03.c",
    "src/faom03.c",       "src/fapa03.c", "src/fasa03.c", "src/faur03.c", "src/fave03.c", "src/fk425.c",  "src/fk45z.c",  "src/fk524.c",
    "src/fk54z.c",        "src/fk52h.c",  "src/fk5hip.c", "src/fk5hz.c",  "src/fw2m.c",   "src/fw2xy.c",  "src/g2icrs.c", "src/gc2gd.c",
    "src/gc2gde.c",       "src/gd2gc.c",  "src/gd2gce.c", "src/gmst00.c", "src/gmst06.c", "src/gmst82.c", "src/gst00a.c", "src/gst00b.c",
    "src/gst06a.c",       "src/gst06.c",  "src/gst94.c",  "src/hd2ae.c",  "src/hd2pa.c",  "src/h2fk5.c",  "src/hfk5z.c",  "src/icrs2g.c",
    "src/ir.c",           "src/jd2cal.c", "src/jdcalf.c", "src/ld.c",     "src/ldn.c",    "src/ldsun.c",  "src/lteceq.c", "src/ltecm.c",
    "src/lteqec.c",       "src/ltpb.c",   "src/ltp.c",    "src/ltpecl.c", "src/ltpequ.c", "src/moon98.c", "src/num00a.c", "src/num00b.c",
    "src/num06a.c",       "src/numat.c",  "src/nut00a.c", "src/nut00b.c", "src/nut06a.c", "src/nut80.c",  "src/nutm80.c", "src/obl06.c",
    "src/obl80.c",        "src/p06e.c",   "src/p2pv.c",   "src/p2s.c",    "src/pap.c",    "src/pas.c",    "src/pb06.c",   "src/pdp.c",
    "src/pfw06.c",        "src/plan94.c", "src/pmat00.c", "src/pmat06.c", "src/pmat76.c", "src/pm.c",     "src/pmp.c",    "src/pmpx.c",
    "src/pmsafe.c",       "src/pn00a.c",  "src/pn00b.c",  "src/pn00.c",   "src/pn06a.c",  "src/pn06.c",   "src/pn.c",     "src/pnm00a.c",
    "src/pnm00b.c",       "src/pnm06a.c", "src/pnm80.c",  "src/pom00.c",  "src/ppp.c",    "src/ppsp.c",   "src/pr00.c",   "src/prec76.c",
    "src/pv2p.c",         "src/pv2s.c",   "src/pvdpv.c",  "src/pvm.c",    "src/pvmpv.c",  "src/pvppv.c",  "src/pvstar.c", "src/pvtob.c",
    "src/pvu.c",          "src/pvup.c",   "src/pvxpv.c",  "src/pxp.c",    "src/refco.c",  "src/rm2v.c",   "src/rv2m.c",   "src/rx.c",
    "src/rxp.c",          "src/rxpv.c",   "src/rxr.c",    "src/ry.c",     "src/rz.c",     "src/s00a.c",   "src/s00b.c",   "src/s00.c",
    "src/s06a.c",         "src/s06.c",    "src/s2c.c",    "src/s2p.c",    "src/s2pv.c",   "src/s2xpv.c",  "src/sepp.c",   "src/seps.c",
    "src/sp00.c",         "src/starpm.c", "src/starpv.c", "src/sxp.c",    "src/sxpv.c",   "src/taitt.c",  "src/taiut1.c", "src/taiutc.c",
    "src/tcbtdb.c",       "src/tcgtt.c",  "src/tdbtcb.c", "src/tdbtt.c",  "src/tf2a.c",   "src/tf2d.c",   "src/tpors.c",  "src/tporv.c",
    "src/tpsts.c",        "src/tpstv.c",  "src/tpxes.c",  "src/tpxev.c",  "src/tr.c",     "src/trxp.c",   "src/trxpv.c",  "src/tttai.c",
    "src/tttcg.c",        "src/tttdb.c",  "src/ttut1.c",  "src/ut1tai.c", "src/ut1tt.c",  "src/ut1utc.c", "src/utctai.c", "src/utcut1.c",
    "src/xy06.c",         "src/xys00a.c", "src/xys00b.c", "src/xys06a.c", "src/zp.c",     "src/zpv.c",    "src/zr.c",     "src/erfaversion.c",
    "src/erfadatextra.c",
};

const public_headers = [_][]const u8{
    "erfa.h",
    "erfam.h",
    "erfaextra.h",
    "erfadatextra.h",
};

const licence_records = [_][]const u8{
    "LICENSE",
    "INFO",
    "NOTICE.md",
    "FORK-LICENSE.md",
    "UPSTREAM.md",
};

const doc_records = [_][]const u8{
    "README.upstream.md",
    "README.rst",
};

const upstream_validation_programs = [_]struct { name: []const u8, source: []const u8 }{
    .{ .name = "t_erfa_c", .source = "src/t_erfa_c.c" },
    .{ .name = "t_erfa_c_extra", .source = "src/t_erfa_c_extra.c" },
};

const facade_source = "zig/root.zig";

const translate_header = "zig/translate.h";

const test_root = "tests.zig";

const smoke_root = "smoke.zig";

const exercise_root = "zig/api_exercise.zig";

const check_targets = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .macos, .abi = .none },
    .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    .{ .cpu_arch = .riscv64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .wasm32, .os_tag = .wasi },
};

const Graph = struct {
    c_lib: *std.Build.Step.Compile,
    module: *std.Build.Module,
    linkage: std.lang.LinkMode,
    runtime_loaded: bool,
};

const Programs = struct {
    tests: *std.Build.Step.Compile,
    exercise: *std.Build.Step.Compile,
    smoke: *std.Build.Step.Compile,
    upstream: [upstream_validation_programs.len]*std.Build.Step.Compile,
};

/// Detect an explicit `-Dtarget`; resolved target options do not preserve that distinction.
fn target_was_named(b: *const std.Build) bool {
    return b.user_input_options.contains("target");
}

/// Windows carries DLLs despite `.none`; WASI has no dynamic linker and cannot carry a shared object.
fn target_carries_shared_object(target: std.Build.ResolvedTarget) bool {
    if (target.result.os.tag == .windows) return true;
    return std.Target.DynamicLinker.kind(target.result.os.tag) != .none;
}

fn shared_object_refusal(b: *std.Build, target: std.Build.ResolvedTarget) ?[]const u8 {
    if (target_carries_shared_object(target)) return null;
    return b.fmt(
        "-Dlinkage=dynamic was requested for {s}, whose OS has no dynamic " ++
            "linker (std.Target.DynamicLinker.kind is .none for that OS), so no " ++
            "shared object can be built or loaded for it. This build does not " ++
            "substitute a different artefact for the one that was asked for; " ++
            "build the static delivery for this target instead, which is the " ++
            "default.",
        .{@tagName(target.result.os.tag)},
    );
}

/// Reject undeliverable shared requests instead of substituting a static archive.
fn resolved_linkage(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    requested: std.lang.LinkMode,
) std.lang.LinkMode {
    if (requested == .dynamic) {
        if (shared_object_refusal(b, target)) |reason| std.debug.panic("erfa: {s}", .{reason});
    }
    return requested;
}

fn graph_prefix(b: *std.Build, target: std.Build.ResolvedTarget) []const u8 {
    const triple = target.result.zigTriple(b.allocator) catch @panic("erfa: unspellable target");
    return b.fmt("{s}-{s}", .{ lib_name, triple });
}

fn delivered_artifact_name(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    linkage: std.lang.LinkMode,
) []const u8 {
    return switch (linkage) {
        .static => b.fmt("lib{s}.a", .{lib_name}),
        .dynamic => switch (target.result.os.tag) {
            .macos, .ios, .tvos, .watchos, .visionos => b.fmt(
                "lib{s}.{d}.{d}.{d}.dylib (link lib{s}.{d}.dylib, soname {s}.{d}.dylib)",
                .{ lib_name, abi_version.major, abi_version.minor, abi_version.patch, lib_name, abi_version.major, lib_name, abi_version.major },
            ),
            .windows => b.fmt("{s}.dll (import library {s}.lib)", .{ lib_name, lib_name }),
            else => b.fmt(
                "lib{s}.so.{d}.{d}.{d} (link lib{s}.so, soname {s}.so.{d})",
                .{ lib_name, abi_version.major, abi_version.minor, abi_version.patch, lib_name, lib_name, abi_version.major },
            ),
        },
    };
}

/// Return the directory required by `src/erfaversion.c:16`'s `<config.h>` include.
fn addGeneratedConfig(b: *std.Build) std.Build.LazyPath {
    const files = b.addWriteFiles();
    // Match upstream's version split rule in `m4/erfa-numver.m4`.
    const parts = splitPackageVersion(package_version);
    _ = files.add("config.h", b.fmt(
        \\/* Generated by build.zig from upstream's recorded version inputs.
        \\ * Do not edit; it is written into the build cache, not this tree.
        \\ *
        \\ * PACKAGE_VERSION is configure.ac:5 (AC_INIT([erfa],[2.0.1])) and
        \\ * meson.build:3 (version: '2.0.1'); the major/minor/micro split
        \\ * reproduces m4/erfa-numver.m4:22-24; SOFA_VERSION is configure.ac:23
        \\ * and meson.build:29. These five macros are the whole of what
        \\ * src/erfaversion.c:15-17 reads from this header.
        \\ */
        \\#ifndef ERFA_CONFIG_H
        \\#define ERFA_CONFIG_H
        \\
        \\#define PACKAGE_VERSION "{s}"
        \\#define PACKAGE_VERSION_MAJOR {d}
        \\#define PACKAGE_VERSION_MINOR {d}
        \\#define PACKAGE_VERSION_MICRO {d}
        \\
        \\#define SOFA_VERSION "{s}"
        \\
        \\#endif /* ERFA_CONFIG_H */
        \\
    , .{ package_version, parts.major, parts.minor, parts.micro, sofa_version }));
    return files.getDirectory();
}

const VersionParts = struct { major: u32, minor: u32, micro: u32 };

fn splitPackageVersion(version: []const u8) VersionParts {
    var fields = std.mem.splitScalar(u8, version, '.');
    const major_text = fields.next() orelse
        std.debug.panic("erfa: recorded package version '{s}' has no component", .{version});
    const minor_text = fields.next() orelse
        std.debug.panic("erfa: recorded package version '{s}' has fewer than three components", .{version});
    const micro_text = fields.next() orelse
        std.debug.panic("erfa: recorded package version '{s}' has fewer than three components", .{version});
    if (fields.next() != null)
        std.debug.panic("erfa: recorded package version '{s}' has more than three components", .{version});
    return .{
        .major = parseVersionComponent(major_text, version),
        .minor = parseVersionComponent(minor_text, version),
        .micro = parseVersionComponent(micro_text, version),
    };
}

fn parseVersionComponent(text: []const u8, version: []const u8) u32 {
    return std.fmt.parseInt(u32, text, 10) catch
        std.debug.panic("erfa: component '{s}' of recorded package version '{s}' is not a number", .{ text, version });
}

/// NetBSD's headers expand `__END_DECLS` to `_Pragma`, which Aro cannot parse.
const AggregateRoute = enum {
    aro,
    preprocessed,
};

/// Use NetBSD's target preprocessor because its headers expand `__END_DECLS` to `_Pragma`.
fn aggregateRoute(target: std.Build.ResolvedTarget) AggregateRoute {
    return if (target.result.os.tag == .netbsd) .preprocessed else .aro;
}

/// Preprocess NetBSD headers with the target compiler.
/// `-dD` preserves macros; `-MD` tracks included headers for cache invalidation.
fn preprocessedAggregate(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    generated: std.Build.LazyPath,
) std.Build.LazyPath {
    const run = b.addSystemCommand(&[_][]const u8{ b.graph.zig_exe, "cc", "-E", "-dD" });
    run.setName("preprocess erfa translate.h");
    if (!target.query.isNative()) {
        const triple = target.query.zigTriple(b.allocator) catch @panic("erfa: unspellable target");
        run.addArg("-target");
        run.addArg(triple);
    }
    run.addPrefixedDirectoryArg("-I", b.path("src"));
    run.addPrefixedDirectoryArg("-I", generated);
    run.addArg("-DHAVE_CONFIG_H=1");
    run.addArg("-o");
    const preprocessed = run.addOutputFileArg("erfa-translate.c");
    run.addArg("-MD");
    _ = run.addPrefixedDepFileOutputArg("-MF", "erfa-translate.d");
    run.addFileArg(b.path(translate_header));
    return preprocessed;
}

const GraphOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    public: bool,
    linkage: std.lang.LinkMode,
    runtime_loaded: bool,
};

/// Build one target's C library and facade.
/// Check graphs use private modules because registered module names are global.
fn addGraph(b: *std.Build, options: GraphOptions) Graph {
    const target = options.target;
    const optimize = options.optimize;
    const public = options.public;
    const linkage = resolved_linkage(b, target, options.linkage);
    const name = if (public) lib_name else graph_prefix(b, target);
    const generated = addGeneratedConfig(b);

    const c_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        // Shared objects require PIC; null keeps static C flags unchanged.
        .pic = if (linkage == .dynamic) true else null,
    });
    c_mod.addIncludePath(b.path("src"));
    c_mod.addIncludePath(generated);
    c_mod.addCMacro("HAVE_CONFIG_H", "1");
    // Upstream links libm as its sole external dependency (`meson.build:32`, `configure.ac:26`).
    c_mod.linkSystemLibrary("m", .{});
    c_mod.addCSourceFiles(.{ .files = &core_sources });

    const c_lib = b.addLibrary(.{
        .name = name,
        .linkage = linkage,
        .version = if (linkage == .dynamic) abi_version else null,
        .root_module = c_mod,
    });
    for (public_headers) |header| {
        c_lib.installHeader(b.path(b.fmt("src/{s}", .{header})), header);
    }

    // Translate the same target and headers as the C compilation.
    const translate = b.addTranslateC(.{
        .root_source_file = switch (aggregateRoute(target)) {
            .aro => b.path(translate_header),
            .preprocessed => preprocessedAggregate(b, target, generated),
        },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    translate.addIncludePath(b.path("src"));
    translate.addIncludePath(generated);
    translate.defineCMacro("HAVE_CONFIG_H", "1");

    const module = if (public)
        b.addModule(lib_name, .{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        })
    else
        b.createModule(.{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
    // Import the translation instead of registering an unlinked `c` module.
    // Runtime mode replaces this import with dispatch from the same translation.
    module.addImport("c", if (options.runtime_loaded)
        runtime_graph.createModule(b, translate, target, optimize)
    else
        translate.createModule());
    // Link the C library only in linked mode; runtime mode uses the provider table.
    if (!options.runtime_loaded) module.linkLibrary(c_lib);
    // The dispatch owns its core module; a second would create incompatible `LoadSource` and `LoadError` types.
    if (!options.runtime_loaded) {
        module.addImport("rt", runtime_graph.createCoreModule(b, target, optimize));
    }

    return .{
        .c_lib = c_lib,
        .module = module,
        .linkage = linkage,
        .runtime_loaded = options.runtime_loaded,
    };
}

fn addUpstreamProgram(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    graph: Graph,
    name: []const u8,
    source: []const u8,
) *std.Build.Step.Compile {
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addIncludePath(b.path("src"));
    mod.linkLibrary(graph.c_lib);
    mod.addCSourceFile(.{ .file = b.path(source) });
    return b.addExecutable(.{ .name = name, .root_module = mod });
}

fn artifactName(b: *std.Build, prefix: []const u8, base: []const u8) []const u8 {
    if (prefix.len == 0) return base;
    return b.fmt("{s}-{s}", .{ prefix, base });
}

fn addPrograms(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    graph: Graph,
    prefix: []const u8,
) Programs {
    const facade = graph.module;

    const test_mod = b.createModule(.{
        .root_source_file = b.path(test_root),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    test_mod.addImport(lib_name, facade);
    // Use LLVM for wide ERFA C signatures.
    const tests = b.addTest(.{ .root_module = test_mod, .use_llvm = true });

    const exercise_mod = b.createModule(.{
        .root_source_file = b.path(exercise_root),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exercise_mod.addImport(lib_name, facade);
    const exercise = b.addExecutable(.{
        .use_llvm = true,
        .name = artifactName(b, prefix, "erfa-exercise"),
        .root_module = exercise_mod,
    });

    const smoke_mod = b.createModule(.{
        .root_source_file = b.path(smoke_root),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    smoke_mod.addImport(lib_name, facade);
    const smoke = b.addExecutable(.{
        .use_llvm = true,
        .name = artifactName(b, prefix, "erfa-smoke"),
        .root_module = smoke_mod,
    });

    var upstream: [upstream_validation_programs.len]*std.Build.Step.Compile = undefined;
    for (upstream_validation_programs, 0..) |program, i| {
        upstream[i] = addUpstreamProgram(
            b,
            target,
            optimize,
            graph,
            artifactName(b, prefix, program.name),
            program.source,
        );
    }

    return .{
        .tests = tests,
        .exercise = exercise,
        .smoke = smoke,
        .upstream = upstream,
    };
}

fn readPackageFile(b: *std.Build, name: []const u8) []u8 {
    b.dependOnFileContents(b.path(name));
    const file = b.root.openFile(b.graph.io, name, .{}) catch |err| {
        std.debug.panic("cannot read {s}: {s}", .{ name, @errorName(err) });
    };
    defer file.close(b.graph.io);

    var reader = file.reader(b.graph.io, &.{});
    return reader.interface.allocRemaining(b.allocator, .limited(1 << 20)) catch |err| {
        std.debug.panic("cannot read {s}: {s}", .{ name, @errorName(err) });
    };
}

/// Render upstream's `erfa.pc.in` with a relocatable prefix and `-lm`.
fn addPkgConfig(b: *std.Build) void {
    const template = readPackageFile(b, "erfa.pc.in");
    var text = std.mem.replaceOwned(u8, b.allocator, template, "@prefix@", "${pcfiledir}/../..") catch @panic("OOM");
    text = std.mem.replaceOwned(u8, b.allocator, text, "@exec_prefix@", "${prefix}") catch @panic("OOM");
    text = std.mem.replaceOwned(u8, b.allocator, text, "@libdir@", "${prefix}/lib") catch @panic("OOM");
    text = std.mem.replaceOwned(u8, b.allocator, text, "@includedir@", "${prefix}/include") catch @panic("OOM");
    text = std.mem.replaceOwned(u8, b.allocator, text, "@VERSION@", package_version) catch @panic("OOM");
    text = std.mem.replaceOwned(u8, b.allocator, text, "@LIBS@", "-lm") catch @panic("OOM");

    // Generate relocatable metadata outside the source tree.
    const files = b.addWriteFiles();
    b.getInstallStep().dependOn(&b.addInstallFileWithDir(
        files.add("erfa.pc", text),
        .lib,
        "pkgconfig/erfa.pc",
    ).step);
}

fn installRecords(b: *std.Build) void {
    for (licence_records) |record| {
        b.getInstallStep().dependOn(&b.addInstallFileWithDir(
            b.path(record),
            .{ .custom = b.fmt("share/licenses/{s}", .{lib_name}) },
            record,
        ).step);
    }
    for (doc_records) |record| {
        b.getInstallStep().dependOn(&b.addInstallFileWithDir(
            b.path(record),
            .{ .custom = b.fmt("share/doc/{s}", .{lib_name}) },
            record,
        ).step);
    }
}

/// Compile each target's programs and reject unsupported shared linkage explicitly.
fn addTargetCheck(
    b: *std.Build,
    step: *std.Build.Step,
    query: std.Target.Query,
    optimize: std.lang.Optimize,
    linkage: std.lang.LinkMode,
    runtime_loaded: bool,
) void {
    const target = b.resolveTargetQuery(query);
    const prefix = graph_prefix(b, target);

    if (linkage == .dynamic) {
        if (shared_object_refusal(b, target)) |reason| {
            step.dependOn(&b.addFail(b.fmt(
                "erfa: check row {s}: {s} No artifact was built for this row, and nothing was substituted for it.",
                .{ prefix, reason },
            )).step);
            return;
        }
    }

    const checked = addGraph(b, .{
        .target = target,
        .optimize = optimize,
        .public = false,
        .linkage = linkage,
        .runtime_loaded = runtime_loaded,
    });
    const programs = addPrograms(b, target, optimize, checked, prefix);
    step.dependOn(&checked.c_lib.step);
    step.dependOn(&programs.tests.step);
    step.dependOn(&programs.exercise.step);
    step.dependOn(&programs.smoke.step);
    for (programs.upstream) |program| step.dependOn(&program.step);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Keep static as the default delivery.
    const requested_linkage = b.option(
        std.lang.LinkMode,
        "linkage",
        "Deliver the native library as a static archive (the default, and " ++
            "exactly what this package produced before the option existed) or " ++
            "as a real shared object carrying upstream's own libtool ABI " ++
            "version, liberfa.so.1.8.1 with the soname liberfa.so.1. This " ++
            "selects the delivery and never the dispatch: the same 249 sources, " ++
            "the same generated config.h, the same four headers, the same " ++
            "translation, the same facade and the same programs are compiled " ++
            "either way. A target whose platform cannot carry a shared object " ++
            "at all -- wasm32-wasi in this package's own matrix, though a " ++
            "Windows target can carry one and is not in that class -- and " ++
            "requesting one there is refused rather than answered with a " ++
            "different artefact. For the selected target that refusal stops the " ++
            "build at configure time; inside `check` the unsupported row becomes " ++
            "an explicit failing step and every other row is still compiled.",
    ) orelse .static;

    // Runtime dispatch is independent of the delivered linkage.
    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Resolve the native entry points at run time instead of linking them, " ++
            "through one process-lifetime table an explicit load(source) fills. " ++
            "The facade keeps the same translated header, the same native types " ++
            "and the same public LoadSource/LoadError; each selected entry " ++
            "point becomes a dispatch through that table, and the module links " ++
            "no archive. Independent of -Dlinkage, which still decides which " ++
            "artefact this build delivers and installs. Default off, and a " ++
            "linked build is unchanged in every respect.",
    ) orelse false;

    const graph = addGraph(b, .{
        .target = target,
        .optimize = optimize,
        .public = true,
        .linkage = requested_linkage,
        .runtime_loaded = runtime_loaded,
    });
    const programs = addPrograms(b, target, optimize, graph, "");

    b.installArtifact(graph.c_lib);
    b.installFile("LICENSE", "LICENSE");
    b.installFile("INFO", "INFO");
    addPkgConfig(b);
    installRecords(b);
    // Compile examples with install; their run steps stay separate.
    b.getInstallStep().dependOn(&programs.smoke.step);
    b.getInstallStep().dependOn(&programs.exercise.step);

    // Disable run caching so smoke checks execute.
    const run_smoke = b.addRunArtifact(programs.smoke);
    run_smoke.has_side_effects = true;
    // Forward arguments after `--` to the smoke program.
    run_smoke.addPassthruArgs();
    b.step("smoke", "Run the smoke example").dependOn(&run_smoke.step);

    const consumer_mod = b.createModule(.{
        .root_source_file = b.path("consumer/src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    consumer_mod.addImport(lib_name, graph.module);
    const consumer = b.addExecutable(.{
        .use_llvm = true,
        .name = "erfa-consumer",
        .root_module = consumer_mod,
    });
    const run_consumer = b.addRunArtifact(consumer);
    run_consumer.has_side_effects = true;
    // Forward arguments after `--` to the consumer.
    run_consumer.addPassthruArgs();
    b.step("consumer", "Run the module consumer").dependOn(&run_consumer.step);

    const run_tests = b.addRunArtifact(programs.tests);
    run_tests.has_side_effects = true;
    const run_exercise = b.addRunArtifact(programs.exercise);
    run_exercise.has_side_effects = true;
    const test_step = b.step("test", "Run the behavioural tests and the facade exercise for the selected target");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_exercise.step);

    var upstream_runs: [upstream_validation_programs.len]*std.Build.Step.Run = undefined;
    for (programs.upstream, 0..) |program, i| {
        const run = b.addRunArtifact(program);
        run.has_side_effects = true;
        upstream_runs[i] = run;
    }
    const upstream_step = b.step("upstream-test", "Run upstream's own t_erfa_c and t_erfa_c_extra validation programs");
    for (upstream_runs) |run| upstream_step.dependOn(&run.step);

    const check_step = b.step(
        "check",
        "Compile the C core, the translated headers, the facade, the exercise, the tests, the smoke example and both upstream validation programs for the six-target matrix, running nothing",
    );
    if (target_was_named(b)) {
        addTargetCheck(b, check_step, target.query, optimize, requested_linkage, runtime_loaded);
    } else {
        for (check_targets) |query| addTargetCheck(b, check_step, query, optimize, requested_linkage, runtime_loaded);
    }

    std.debug.print("erfa: {s}, {d} core translation units, 4 public headers, config.h generated from configure.ac and m4/erfa-numver.m4\n", .{
        delivered_artifact_name(b, target, graph.linkage),
        core_sources.len,
    });
    if (runtime_loaded) {
        std.debug.print(
            "erfa: provider dispatch (-Druntime=true); no library is linked " ++
                "into the module, and a provider is named by an explicit " ++
                "load(source). The artefact above is still built and installed.\n",
            .{},
        );
    }
}
