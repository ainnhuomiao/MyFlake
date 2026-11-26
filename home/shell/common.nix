# 物理机与 WSL 共用的 Shell 环境（不含桌面终端模拟器的配置）
{ pkgs, ... }:
{
  imports = [
    ./fish
    ./starship.nix
    ./eza.nix
  ];
  home.packages = [ pkgs.tree ];
}
