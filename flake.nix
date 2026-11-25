{
  description = "Development environment for the mbtlint MoonBit library";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    moonbit-overlay = {
      url = "github:moonbit-community/moonbit-overlay/85573a36872d7fa6f8753ea0da7bdbe056d6301f";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, moonbit-overlay, ... }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forEachSystem = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forEachSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ moonbit-overlay.overlays.default ];
          };
          shell = pkgs.mkShell {
            packages = [
              pkgs.moonbit-bin."v0.10.22+124d61d05+738607b"
              pkgs.jq
              pkgs.perl
              pkgs.python3
            ];
          };
        in
        {
          default = shell;
          ci = shell;
        }
      );
    };
}
