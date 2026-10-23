
{
  description = "ERFA — Essential Routines for Fundamental Astronomy, packaged for Zig 0.16";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/c7def046b9a883d46974757852106483d741586f";
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
        zig = pkgs.zig_0_16;
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
        default = pkgs.mkShell { packages = [ pkgs.zig_0_16 ]; };
      });
    };
}
