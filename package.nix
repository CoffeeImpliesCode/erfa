
{ lib
, stdenv
, zig
, linkage ? "static"
, optimize ? "Debug"
}:

let
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
  version = "2.0.1-dev.1a8044cd";

  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: type: keep (baseNameOf (toString path));
  };

  strictDeps = true;
  nativeBuildInputs = [ zig ];

  # Skip setup-hook phases; `installPhase` builds and installs this variant.
  dontConfigure = true;
  dontBuild = true;
  dontCheck = true;
  dontUseZigCheck = true;

  installPhase = ''
    runHook preInstall

    # Default Zig caches to `TMPDIR`; caller-supplied paths remain intact.
    export ZIG_LOCAL_CACHE_DIR="''${TMPDIR:-/tmp}/zig-local"
    export ZIG_GLOBAL_CACHE_DIR="''${TMPDIR:-/tmp}/zig-global"

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
    upstream-commit = "1a8044cde5b7763295d472a6443387239127c6c8";
    upstream-version = "2.0.1";
  };

  meta = {
    description = "Essential Routines for Fundamental Astronomy";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
}
