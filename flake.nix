
{
  description = "ERFA — Essential Routines for Fundamental Astronomy, packaged for Zig 0.17";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/02c087f3fe673c9e317f206a627cb6b910336dbe";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      mkErfa = pkgs: linkage: pkgs.callPackage ./package.nix {
        zig = pkgs.zig_0_17;
        inherit linkage;
      };
    in
    {
      packages = forAllSystems (pkgs: {
        default = mkErfa pkgs "static";
        static = mkErfa pkgs "static";
        shared = mkErfa pkgs "dynamic";
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell { packages = [ pkgs.zig_0_17 ]; };
      });
    };
}
