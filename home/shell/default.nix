{ pkgs, ... }:
{
  imports = [
    ./fish
    ./starship.nix
    ./eza.nix
    ./kitty.nix
  ];
  home.packages = [ pkgs.tree ];
}
