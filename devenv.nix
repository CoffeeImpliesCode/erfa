
{ pkgs, lib, ... }:

let
  zig = pkgs.zig_0_16;
  mkErfa = linkage: pkgs.callPackage ./package.nix { inherit zig; inherit linkage; };

  # Tasks need the SDK root because devenv starts them in the caller's directory.
  sdkRoot = builtins.toString ./.;

  # Keep Zig's build cache outside the source tree.
  cacheDir = "$ZIG_LOCAL_CACHE_DIR/erfa/cache";

  # Initialize caches in task bodies; single-task mode skips `enterShell`.
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

    # Require an external prefix because the default install path is inside the checkout.
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
    # Require an external prefix for the shared install.
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
    # Run from the SDK root because `sha256sum` resolves relative paths.
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
