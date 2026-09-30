{ pkgs, ... }:
{
  home.packages = [
    pkgs.rust-bin.stable.latest.default
    pkgs.rust-analyzer
  ];
}
