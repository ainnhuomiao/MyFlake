{
  inputs,
  ...
}:
let
  nixpkgsCfg = import ../../flake/nixpkgs.nix { inherit inputs; };
in
{
  nixpkgs = {
    inherit (nixpkgsCfg) config;
    overlays = nixpkgsCfg.overlays ++ [
      inputs.rust-overlay.overlays.default
    ];
  };
}
