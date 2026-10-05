# Canonical development environment. `outputs` are lazy: entering the shell
# does not build the library, and `devenv build outputs.static` /
# `outputs.shared` are the packaging route. Both call the same package.nix the
# flake uses; the SDK is deliberately not in `packages`.
# Every task below begins by changing directory to `sdkRoot`. devenv materialises
# a task as a generated program that runs with the *caller's* working directory,
# not this file's directory, so `devenv tasks run sdk:consumer` from a scratch
# project would otherwise run `zig build` where there is no `build.zig`, and
# `sha256sum -c UPSTREAM.sha256` where there is no `UPSTREAM.sha256`. The root is
# therefore named here, from this file, rather than read from `$DEVENV_ROOT`,
# which is the project directory and is exactly what fails.
#
# No host path is written here. Scratch, cache and runtime-socket variables come
# from the caller and are never unset by this file.

{ pkgs, lib, ... }:

let
  zig = pkgs.zig_0_16;
  mkErfa = linkage: pkgs.callPackage ./package.nix { inherit zig; inherit linkage; };

  # This SDK's own directory, from the file that declares it. `builtins.toString`
  # rather than an interpolated `${./.}`: the interpolated form can pull the whole
  # tree into the read-only Nix store, and a store copy is not a tree `zig build`
  # may write a cache into. Every use goes through `lib.escapeShellArg`, so a path
  # containing a space is still one argument.
  sdkRoot = builtins.toString ./.;

  # Where a run puts what it generates. Left to itself `zig build` writes
  # `.zig-cache` **inside the checkout**, and this is a network mount, so every
  # route below names an external directory instead. The path is assembled here
  # in Nix and expanded by the shell when a task runs, because the location is
  # the caller's rather than this file's.
  cacheDir = "$ZIG_LOCAL_CACHE_DIR/erfa/cache";

  # The Zig caches, completed — never overwritten — before any body starts a
  # compiler. An exported `ZIG_LOCAL_CACHE_DIR` or `ZIG_GLOBAL_CACHE_DIR` is the
  # caller's and wins; an unset one is completed from `$XDG_CACHE_HOME`, where
  # a cache belongs by the Base Directory Specification, and then from
  # `$TMPDIR`, the host's own scratch policy. With neither naming a location the
  # task says so on stderr and stops, rather than being handed one this file does
  # not get to invent: `/tmp` and `/var/tmp` are never defaults here, and no
  # branch names the repository.
  #
  # This is the task body, not only `enterShell`. `devenv tasks run --mode
  # single` starts a generated program that never sources the shell hook, so a
  # fill that lived in `enterShell` alone would leave that program building
  # against Zig's own `.zig-cache` in this checkout.
  cacheFill = ''
    erfa_cache=""
    if [ -n "''${XDG_CACHE_HOME:-}" ]; then
      erfa_cache="$XDG_CACHE_HOME/erfa"
    elif [ -n "''${TMPDIR:-}" ]; then
      erfa_cache="$TMPDIR/erfa"
    fi
    if [ -z "''${ZIG_GLOBAL_CACHE_DIR:-}" ] || [ -z "''${ZIG_LOCAL_CACHE_DIR:-}" ]; then
      if [ -z "$erfa_cache" ]; then
        echo "erfa devenv: no Zig cache location is named. Export" >&2
        echo "ZIG_LOCAL_CACHE_DIR and ZIG_GLOBAL_CACHE_DIR at an approved" >&2
        echo "mount, or set XDG_CACHE_HOME or TMPDIR; no location is chosen" >&2
        echo "here." >&2
        exit 1
      fi
      : "''${ZIG_GLOBAL_CACHE_DIR:=$erfa_cache/zig-global}"
      : "''${ZIG_LOCAL_CACHE_DIR:=$erfa_cache/zig-local}"
      export ZIG_GLOBAL_CACHE_DIR ZIG_LOCAL_CACHE_DIR
    fi
  '';

  # What every `zig build` body opens with: this checkout, then the cache fill.
  preamble = ''
    cd ${lib.escapeShellArg sdkRoot}
    ${cacheFill}
  '';
in
{
  packages = [
    zig
    pkgs.pkg-config
  ];

  outputs = {
    default = mkErfa "static";
    static = mkErfa "static";
    shared = mkErfa "dynamic";
  };

  assertions = [
    {
      assertion = zig.version == "0.16.0";
      message = "The ERFA SDK is pinned to Zig 0.16.0.";
    }
  ];

  tasks = {
    # Every `zig build` route below is written in the same order: `preamble`
    # first, which is this checkout and then the cache fill; then the step name;
    # then `--cache-dir "${cacheDir}"`; then `--prefix` on the two steps that
    # install something; then any `-D`; then `-j8 --summary all`. Those are the
    # flags `AGENTS.md`'s per-library recipe asks for, and they are written into
    # each body rather than appended from outside, because `devenv tasks run`
    # takes no trailing arguments: nothing can add a job count, a cache or a
    # summary to a task once this file has been evaluated. The two tasks that
    # run no compiler — `sdk:licence`, a `sha256sum -c`, and `sdk:fmt`, a
    # `zig fmt` — keep the change of directory and nothing else.

    # The default step is an installing one: `build.zig` puts the artefact, the
    # four headers, `erfa.pc` and the licence/doc records on the install step.
    # `zig build`'s own default prefix is `zig-out/` **inside the checkout**, so
    # it is given an external one rather than writing delivery output onto the
    # working tree's own filesystem: `$ERFA_INSTALL_PREFIX` if the caller
    # exported it, else `$ZIG_LOCAL_CACHE_DIR/erfa/build` if that is exported,
    # else `$TMPDIR/erfa/build` if that is exported. There is no fourth default —
    # this file does not get to invent a scratch location — so with none of the
    # three exported the task says so on stderr and stops. `preamble` has filled
    # an unset `ZIG_LOCAL_CACHE_DIR` by the time this chain runs, so a run whose
    # caller exported nothing still lands outside this tree; a value the caller
    # did export is used as it is, and nothing here sets or unsets anything else.
    "sdk:build" = {
      description = "zig build (the 249-unit core, the translation, the facade), installed outside this tree";
      exec = ''
        ${preamble}
        if [ -n "''${ERFA_INSTALL_PREFIX:-}" ]; then
          prefix="''${ERFA_INSTALL_PREFIX}"
        elif [ -n "''${ZIG_LOCAL_CACHE_DIR:-}" ]; then
          prefix="''${ZIG_LOCAL_CACHE_DIR}/erfa/build"
        elif [ -n "''${TMPDIR:-}" ]; then
          prefix="''${TMPDIR}/erfa/build"
        else
          echo "erfa devenv: no install prefix is available. Export" >&2
          echo "ERFA_INSTALL_PREFIX, or ZIG_LOCAL_CACHE_DIR, or TMPDIR, and" >&2
          echo "run this task again; no location is chosen here." >&2
          exit 1
        fi
        mkdir -p "$prefix"
        zig build --cache-dir "${cacheDir}" --prefix "$prefix" -j8 --summary all
      '';
    };
    "sdk:test" = {
      description = "zig build test (51 behavioural tests plus the facade exercise)";
      exec = ''
        ${preamble}
        zig build test --cache-dir "${cacheDir}" -j8 --summary all
      '';
    };
    "sdk:smoke" = {
      description = "zig build smoke";
      exec = ''
        ${preamble}
        zig build smoke --cache-dir "${cacheDir}" -j8 --summary all
      '';
    };
    "sdk:consumer" = {
      description = "zig build consumer (run the module consumer)";
      exec = ''
        ${preamble}
        zig build consumer --cache-dir "${cacheDir}" -j8 --summary all
      '';
    };
    "sdk:upstream-test" = {
      description = "zig build upstream-test (t_erfa_c and t_erfa_c_extra)";
      exec = ''
        ${preamble}
        zig build upstream-test --cache-dir "${cacheDir}" -j8 --summary all
      '';
    };
    "sdk:check" = {
      description = "zig build check (six-target compile matrix; runs nothing)";
      exec = ''
        ${preamble}
        zig build check --cache-dir "${cacheDir}" -j8 --summary all
      '';
    };
    # The delivery-output task. The prefix is external to this checkout and
    # chosen from what the caller exported: `ERFA_INSTALL` first, then the Zig
    # local cache the shell already carries, then `$TMPDIR`. No branch of it can
    # land inside the repository, and with none of the three exported there is
    # no prefix at all rather than an invented one. `preamble` has filled an
    # unset `ZIG_LOCAL_CACHE_DIR` before this chain runs, so the second branch
    # is normally the one that decides; a value the caller exported is used as
    # it is, and `--cache-dir` above names that same directory.
    "sdk:shared-install" = {
      description = "zig build install -Dlinkage=dynamic into $ERFA_INSTALL, else $ZIG_LOCAL_CACHE_DIR/erfa/shared, else $TMPDIR/erfa/shared";
      exec = ''
        ${preamble}
        if [ -n "''${ERFA_INSTALL:-}" ]; then
          prefix="''${ERFA_INSTALL}"
        elif [ -n "''${ZIG_LOCAL_CACHE_DIR:-}" ]; then
          prefix="''${ZIG_LOCAL_CACHE_DIR}/erfa/shared"
        elif [ -n "''${TMPDIR:-}" ]; then
          prefix="''${TMPDIR}/erfa/shared"
        else
          echo "erfa devenv: no install prefix is available. Export" >&2
          echo "ERFA_INSTALL, or ZIG_LOCAL_CACHE_DIR, or TMPDIR, and run this" >&2
          echo "task again; no location is chosen here." >&2
          exit 1
        fi
        mkdir -p "$prefix"
        zig build install --cache-dir "${cacheDir}" --prefix "$prefix" -Dlinkage=dynamic -j8 --summary all
      '';
    };
    # The integrity gate, kept under the name this SDK has always used for it.
    # `sha256sum -c` resolves every path in the record against the working
    # directory, so this one has to change directory rather than merely name
    # the record by absolute path.
    "sdk:licence" = {
      description = "sha256sum -c UPSTREAM.sha256 (268 retained upstream files)";
      exec = ''
        cd ${lib.escapeShellArg sdkRoot}
        sha256sum -c UPSTREAM.sha256
      '';
    };
    "sdk:fmt" = {
      description = "zig fmt over this fork's own Zig files";
      exec = ''
        cd ${lib.escapeShellArg sdkRoot}
        zig fmt build.zig build.zig.zon tests.zig smoke.zig \
          zig/root.zig zig/api_exercise.zig consumer/build.zig \
          consumer/build.zig.zon consumer/src/main.zig
      '';
    };
  };

  enterShell = ''
    ${cacheFill}
    echo "ERFA SDK — Zig ${zig.version}"
    echo "  devenv build outputs.static   # the SDK's own linkage policy"
    echo "  devenv build outputs.shared   # -Dlinkage=dynamic"
    echo "  devenv tasks                   # sdk:build, sdk:test, sdk:check, ..."
    echo "  sdk:build, sdk:shared-install   # install to an external --prefix, never zig-out/"
    echo "  cache:      ''${ZIG_LOCAL_CACHE_DIR:-unset}/erfa/cache, global ''${ZIG_GLOBAL_CACHE_DIR:-unset}"
    echo
    echo "A Zig consumer of this module MUST set .use_llvm = true on its own"
    echo "executable/test root. See README.md section 4.1."
  '';
}
