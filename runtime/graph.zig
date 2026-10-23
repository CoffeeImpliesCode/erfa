// SPDX-License-Identifier: BSD-3-Clause

const std = @import("std");

// Must match `runtime/sync.c`'s prefix and the symbol names in `runtime/library.zig`.
const sync_prefix = "erfa_rt";

// Keep C-library declarations direct; runtime providers need not export them.
const libc_noise =
    \\__acos,__acosf,__acosh,__acoshf,__acoshl,__acosl,__acospi,__acospif,__acospil,__asin,
    \\__asinf,__asinh,__asinhf,__asinhl,__asinl,__asinpi,__asinpif,__asinpil,__atan,__atan2,
    \\__atan2f,__atan2l,__atan2pi,__atan2pif,__atan2pil,__atanf,__atanh,__atanhf,__atanhl,
    \\__atanl,__atanpi,__atanpif,__atanpil,__cbrt,__cbrtf,__cbrtl,__ceil,__ceilf,__ceill,
    \\__compoundn,__compoundnf,__compoundnl,__copysign,__copysignf,__copysignl,__cos,__cosf,
    \\__cosh,__coshf,__coshl,__cosl,__cospi,__cospif,__cospil,__drem,__dremf,__dreml,__erf,
    \\__erfc,__erfcf,__erfcl,__erff,__erfl,__exp,__exp10,__exp10f,__exp10l,__exp10m1,__exp10m1f,
    \\__exp10m1l,__exp2,__exp2f,__exp2l,__exp2m1,__exp2m1f,__exp2m1l,__expf,__expl,__expm1,
    \\__expm1f,__expm1l,__fabs,__fabsf,__fabsl,__fdim,__fdimf,__fdiml,__floor,__floorf,__floorl,
    \\__fma,__fmaf,__fmal,__fmax,__fmaxf,__maximum,__maximum_mag,__maximum_mag_num,
    \\__maximum_mag_numf,__maximum_mag_numl,__maximum_magf,__maximum_magl,__maximum_num,
    \\__maximum_numf,__maximum_numl,__maximumf,__maximuml,__fmaxl,__fmaxmag,__fmaxmagf,
    \\__fmaxmagl,__fmin,__fminf,__minimum,__minimum_mag,__minimum_mag_num,__minimum_mag_numf,
    \\__minimum_mag_numl,__minimum_magf,__minimum_magl,__minimum_num,__minimum_numf,
    \\__minimum_numl,__minimumf,__minimuml,__fminl,__fminmag,__fminmagf,__fminmagl,__fmod,
    \\__fmodf,__fmodl,__fpclassify,__fpclassifyd128,__fpclassifyd32,__fpclassifyd64,
    \\__fpclassifyf,__fpclassifyl,__frexp,__frexpf,__frexpl,__fromfp,__fromfpf,__fromfpl,
    \\__fromfpx,__fromfpxf,__fromfpxl,__gamma,__gammaf,__gammal,__getpayload,__getpayloadf,
    \\__getpayloadl,__hypot,__hypotf,__hypotl,__ilogb,__ilogbf,__ilogbl,__isnan,__isnand128,
    \\__isnand32,__isnand64,__isnanf,__isnanl,__j0,__j0f,__j0l,__j1,__j1f,__j1l,__jn,__jnf,__jnl,
    \\__ldexp,__ldexpf,__ldexpl,__lgamma,__lgamma_r,__lgammaf,__lgammaf_r,__lgammal,__lgammal_r,
    \\__llogb,__llogbf,__llogbl,__llrint,__llrintf,__llrintl,__llround,__llroundf,__llroundl,
    \\__log,__log10,__log10f,__log10l,__log10p1,__log10p1f,__log10p1l,__log1p,__log1pf,__log1pl,
    \\__log2,__log2f,__log2l,__log2p1,__log2p1f,__log2p1l,__logb,__logbf,__logbl,__logf,__logl,
    \\__logp1,__logp1f,__logp1l,__lrint,__lrintf,__lrintl,__lround,__lroundf,__lroundl,__modf,
    \\__modff,__modfl,__nan,__nanf,__nanl,__nearbyint,__nearbyintf,__nearbyintl,__nextafter,
    \\__nextafterf,__nextafterl,__nextdown,__nextdownf,__nextdownl,__nexttoward,__nexttowardf,
    \\__nexttowardl,__nextup,__nextupf,__nextupl,__nldbl_nexttowardf,__pow,__powf,__powl,__pown,
    \\__pownf,__pownl,__powr,__powrf,__powrl,__remainder,__remainderf,__remainderl,__remquo,
    \\__remquof,__remquol,__rint,__rintf,__rintl,__rootn,__rootnf,__rootnl,__round,__roundeven,
    \\__roundevenf,__roundevenl,__roundf,__roundl,__rsqrt,__rsqrtf,__rsqrtl,__scalb,__scalbf,
    \\__scalbl,__scalbln,__scalblnf,__scalblnl,__scalbn,__scalbnf,__scalbnl,__signbit,
    \\__signbitd128,__signbitd32,__signbitd64,__signbitf,__signbitl,__significand,__significandf,
    \\__significandl,__sin,__sincos,__sincosf,__sincosl,__sinf,__sinh,__sinhf,__sinhl,__sinl,
    \\__sinpi,__sinpif,__sinpil,__sqrt,__sqrtf,__sqrtl,__tan,__tanf,__tanh,__tanhf,__tanhl,
    \\__tanl,__tanpi,__tanpif,__tanpil,__tgamma,__tgammaf,__tgammal,__trunc,__truncf,__truncl,
    \\__ufromfp,__ufromfpf,__ufromfpl,__ufromfpx,__ufromfpxf,__ufromfpxl,__y0,__y0f,__y0l,__y1,
    \\__y1f,__y1l,__yn,__ynf,__ynl,_chgsignl,acos,acosf,acosh,acoshf,acoshl,acosl,acospi,acospif,
    \\acospil,asin,asinf,asinh,asinhf,asinhl,asinl,asinpi,asinpif,asinpil,atan,atan2,atan2f,
    \\atan2l,atan2pi,atan2pif,atan2pil,atanf,atanh,atanhf,atanhl,atanl,atanpi,atanpif,atanpil,
    \\cbrt,cbrtf,cbrtl,ceil,ceilf,ceill,compoundn,compoundnf,compoundnl,copysign,copysignf,
    \\copysignl,cos,cosf,cosh,coshf,coshl,cosl,cospi,cospif,cospil,drem,dremf,dreml,erf,erfc,
    \\erfcf,erfcl,erff,erfl,exp,exp10,exp10f,exp10l,exp10m1,exp10m1f,exp10m1l,exp2,exp2f,exp2l,
    \\exp2m1,exp2m1f,exp2m1l,expf,expl,expm1,expm1f,expm1l,fabs,fabsf,fabsl,fdim,fdimf,fdiml,
    \\finite,finitef,floor,floorf,floorl,fma,fmaf,fmal,fmax,fmaxf,fmaximum,fmaximum_mag,
    \\fmaximum_mag_num,fmaximum_mag_numf,fmaximum_mag_numl,fmaximum_magf,fmaximum_magl,
    \\fmaximum_num,fmaximum_numf,fmaximum_numl,fmaximumf,fmaximuml,fmaxl,fmaxmag,fmaxmagf,
    \\fmaxmagl,fmin,fminf,fminimum,fminimum_mag,fminimum_mag_num,fminimum_mag_numf,
    \\fminimum_mag_numl,fminimum_magf,fminimum_magl,fminimum_num,fminimum_numf,fminimum_numl,
    \\fminimumf,fminimuml,fminl,fminmag,fminmagf,fminmagl,fmod,fmodf,fmodl,frexp,frexpf,frexpl,
    \\fromfp,fromfpf,fromfpl,fromfpx,fromfpxf,fromfpxl,gamma,gammaf,gammal,getpayload,
    \\getpayloadf,getpayloadl,hypot,hypotf,hypotl,ilogb,ilogbf,ilogbl,j0,j0f,j0l,j1,j1f,j1l,jn,
    \\jnf,jnl,ldexp,ldexpf,ldexpl,lgamma,lgamma_r,lgammaf,lgammaf_r,lgammal,lgammal_r,llogb,
    \\llogbf,llogbl,llrint,llrintf,llrintl,llround,llroundf,llroundl,log,log10,log10f,log10l,
    \\log10p1,log10p1f,log10p1l,log1p,log1pf,log1pl,log2,log2f,log2l,log2p1,log2p1f,log2p1l,logb,
    \\logbf,logbl,logf,logl,logp1,logp1f,logp1l,lrint,lrintf,lrintl,lround,lroundf,lroundl,modf,
    \\modff,modfl,nan,nanf,nanl,nearbyint,nearbyintf,nearbyintl,nextafter,nextafterf,nextafterl,
    \\nextdown,nextdownf,nextdownl,nexttoward,nexttowardf,nexttowardl,nextup,nextupf,nextupl,pow,
    \\pow10,pow10f,pow10l,powf,powl,pown,pownf,pownl,powr,powrf,powrl,remainder,remainderf,
    \\remainderl,remquo,remquof,remquol,rint,rintf,rintl,rootn,rootnf,rootnl,round,roundeven,
    \\roundevenf,roundevenl,roundf,roundl,rsqrt,rsqrtf,rsqrtl,scalb,scalbf,scalbl,scalbln,
    \\scalblnf,scalblnl,scalbn,scalbnf,scalbnl,significand,significandf,significandl,sin,sincos,
    \\sincosf,sincosl,sinf,sinh,sinhf,sinhl,sinl,sinpi,sinpif,sinpil,sqrt,sqrtf,sqrtl,tan,tanf,
    \\tanh,tanhf,tanhl,tanl,tanpi,tanpif,tanpil,tgamma,tgammaf,tgammal,trunc,truncf,truncl,
    \\ufromfp,ufromfpf,ufromfpl,ufromfpx,ufromfpxf,ufromfpxl,y0,y0f,y0l,y1,y1f,y1l,yn,ynf,ynl,
    \\__ceilf16,__copysignf16,__fabsf16,__finite,__finitef,__finitef128,__finitel,__floorf16,
    \\__fmaf16,__fmaxf16,__fminf16,__fpclassifyd,__fpclassifyf128,__hypotf16,__imp__HUGE,__inf,
    \\__inff,__infinity,__infl,__inline_isfinited,__inline_isfinitel,__inline_isinfd,
    \\__inline_isinfl,__inline_isnormall,__iseqsig,__iseqsigf,__iseqsigf128,__iseqsigl,__isfinite,
    \\__isfinitef,__isfinitel,__isinf,__isinff,__isinff128,__isinfl,__isnanf128,__isnormal,
    \\__isnormalf,__isnormall,__issignaling,__issignalingf,__issignalingf128,__issignalingl,
    \\__math_errhandling,__mingw_get_crt_info,__mingw_raise_matherr,__mingw_setusermatherr,
    \\__nextafterf16,__prefetch,__rintf16,__roundf16,__setusermatherr,__signbitf128,__sincos_stret,
    \\__sincosf_stret,__sincospi_stret,__sincospif_stret,__sqrtf16,__truncf16,_atof_l,_cabs,
    \\_chgsign,_chgsignf,_copysign,_copysignf,_finite,_finitef,_fpclass,_fpclassf,_hypot,_isnan,
    \\_isnanf,_j0,_j1,_jn,_logb,_logbf,_matherr,_nextafter,_nextafterf,_scalb,_y0,_y1,_yn,abs,atof,
    \\chgsign,finitel,fpclass,gamma_r,gammaf_r,isinf,isinff,isinfl,isnan,isnanf,isnanl,labs,rinttol,
    \\roundtol,signgam
;

const provider_optional = "";

const provider_excluded = "";

/// Creates the loader module for linked builds; runtime builds create it with the dispatch.
pub fn createCoreModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path("runtime/loader.zig"),
        .target = target,
        .optimize = optimize,
        // The Unix backend calls `dlopen` through libc; linked builds do not compile this module.
        .link_libc = true,
    });
}

/// Creates the runtime-loaded C module from the translation for this target.
pub fn createModule(
    b: *std.Build,
    translate: *std.Build.Step.TranslateC,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
) *std.Build.Module {
    const core = createCoreModule(b, target, optimize);

    const library = b.createModule(.{
        .root_source_file = b.path("runtime/library.zig"),
        .target = target,
        .optimize = optimize,
    });
    library.addImport("rt", core);

    return createDispatchModule(b, translate, target, optimize, core, library);
}

const GeneratedSources = struct {
    native: std.Build.LazyPath,
    dispatch: std.Build.LazyPath,
};

fn createDispatchModule(
    b: *std.Build,
    translate: *std.Build.Step.TranslateC,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    core: *std.Build.Module,
    library: *std.Build.Module,
) *std.Build.Module {
    const sources = generateDispatch(b, translate, target);

    const dispatch = b.createModule(.{
        .root_source_file = sources.dispatch,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    dispatch.addImport("rt", core);
    dispatch.addImport("library", library);
    // Use the patched root so macro-expanded calls resolve through routed wrappers.
    const native = b.createModule(.{
        .root_source_file = sources.native,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    native.addImport("c_routed", dispatch);
    dispatch.addImport("c_native", native);
    dispatch.addCSourceFiles(.{
        .files = &.{"runtime/sync.c"},
        .flags = &.{b.fmt("-DRT_SYNC_PREFIX={s}", .{sync_prefix})},
        .language = .c,
    });
    return dispatch;
}

fn generateDispatch(
    b: *std.Build,
    translate: *std.Build.Step.TranslateC,
    target: std.Build.ResolvedTarget,
) GeneratedSources {
    const generator = b.addExecutable(.{
        .name = b.fmt("erfa-runtime-generate-{s}", .{
            target.result.zigTriple(b.allocator) catch @panic("unspellable target"),
        }),
        .root_module = b.createModule(.{
            .root_source_file = b.path("runtime/generate.zig"),
            .target = b.graph.host,
            .optimize = .debug,
        }),
    });

    const run = b.addRunArtifact(generator);
    run.addArg("--library");
    run.addArg("erfa");
    run.addArg("--translate");
    run.addFileArg(translate.getOutput());
    if (libc_noise.len != 0) {
        run.addArg("--noise");
        run.addArg(libc_noise);
    }
    if (provider_optional.len != 0) {
        run.addArg("--optional");
        run.addArg(provider_optional);
    }
    if (provider_excluded.len != 0) {
        run.addArg("--exclude");
        run.addArg(provider_excluded);
    }
    run.addArg("--native-output");
    const native_source = run.addOutputFileArg("native.zig");
    run.addArg("--output");
    const dispatch_source = run.addOutputFileArg("dispatch.zig");
    return .{ .native = native_source, .dispatch = dispatch_source };
}
