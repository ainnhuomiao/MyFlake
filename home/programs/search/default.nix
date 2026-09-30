{ pkgs, appearance, ... }:
let
  c = appearance.catppuccin;
  h = appearance.toHex;
in
{
  home = {
    packages = with pkgs; [
      fd
      ripgrep
    ];
  };
  programs = {
    fzf = {
      enable = true;
      colors = {
        "bg" = h c.base;
        "bg+" = h c.surface0;
        "fg" = h c.text;
        "fg+" = h c.text;
        "hl" = h c.red;
        "hl+" = h c.red;
        "info" = h c.mauve;
        "prompt" = h c.mauve;
        "pointer" = h c.peach;
        "marker" = h c.peach;
        "spinner" = h c.peach;
        "header" = h c.red;
        "border" = h c.mauve;
      };
    };
    bat = {
      enable = true;
      config.theme = "Catppuccin ${appearance.catppuccinName}";
    };
  };

  imports = [
    ./s.nix
  ];
}
