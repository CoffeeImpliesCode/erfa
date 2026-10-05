# One source-only derivation, consumed by flake.nix and devenv.nix through
# pkgs.callPackage. Both pass zig = pkgs.zig_0_16.
#
# linkage: "static" is the SDK's own policy and the default; "dynamic" is the
# shared object. "Static" means a static library artefact, never a promise of a
# wholly static executable.
#
# The build graph owns the source list, the C flags, the generated config.h and
# the whole install layout. This derivation adds exactly one thing: the variant
# selection and the Nix-provided caches.

{ lib
, stdenv
, zig
, linkage ? "static"
, optimize ? "Debug"
}:

let
  # No host path, no sibling, no fixed-output hash: the source is this directory.
  # Only build and tooling state named here is excluded. Matching the basename
  # holds at any depth, and it keeps upstream's dotfiles - UPSTREAM.sha256
  # records `.github/workflows/ci_workflows.yml` among its 323 entries, so a
  # filter that dropped every dotfile could never be checked against the tree it
  # was made from.
  keep = name:
    !(lib.elem name [
      ".git"
      ".jj"
      ".devenv"
      ".devenv.flake.nix"
      ".direnv"
      "zig-cache"
      ".zig-cache"
      "zig-out"
      "zig-pkg"
      "result"
    ])
    && !(lib.hasPrefix "result-" name);
in

assert zig.version == "0.16.0" ||
  builtins.throw "erfa: 'zig' must be pkgs.zig_0_16, got ${zig.version}";

assert lib.elem linkage [ "static" "dynamic" ];

stdenv.mkDerivation {
  pname = "erfa";
  # build.zig.zon's version. The commit rides in the pre-release field because
  # this tree is upstream master past the v2.0.1 tag, not the release.
  version = "2.0.1-dev.1a8044cd";

  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: type: keep (baseNameOf (toString path));
  };

  strictDeps = true;
  nativeBuildInputs = [ zig ];

  # Install only. The Zig setup hook's configure/build/check phases are unused
  # and must not run: a default-flag build followed by a variant install would
  # compile the tree twice. dontInstall is deliberately not set, or the real
  # installPhase below would never execute.
  dontConfigure = true;
  dontBuild = true;
  dontCheck = true;
  dontUseZigCheck = true;

  installPhase = ''
    runHook preInstall

    # Caches under the Nix-provided TMPDIR, outside the unpacked source tree.
    # These are defaults only: a caller-supplied cache is honoured, never unset.
    export ZIG_LOCAL_CACHE_DIR="''${TMPDIR:-/tmp}/zig-local"
    export ZIG_GLOBAL_CACHE_DIR="''${TMPDIR:-/tmp}/zig-global"

    # One invocation, one optimize selection, one variant. `zig build install`
    # writes the artefact, the four public headers, erfa.pc, the licence and
    # provenance records and LICENSE/INFO; nothing else is written to $out here.
    zig build install \
      --prefix "$out" \
      -Doptimize=${optimize} \
      -Dcpu=baseline \
      -Dlinkage=${linkage} \
      -j"''${NIX_BUILD_CORES:-1}"

    runHook postInstall
  '';

  passthru = {
    inherit linkage;
    # UPSTREAM.md section 1 is the authority for both values.
    upstream-commit = "1a8044cde5b7763295d472a6443387239127c6c8";
    upstream-version = "2.0.1";
  };

  meta = {
    description = "Essential Routines for Fundamental Astronomy";
    # LICENSE, with the SOFA derivation preamble. NOTICE.md holds the per-file
    # inventory; FORK-LICENSE.md the grant for this fork's own files.
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
}
