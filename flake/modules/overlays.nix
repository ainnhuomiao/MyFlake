{ inputs, ... }:
let
  nixpkgsCfg = import ../nixpkgs.nix { inherit inputs; };
in
{
  flake.overlays.default = inputs.nixpkgs.lib.composeManyExtensions nixpkgsCfg.overlays;
}
