{ pkgs, me, ... }:
{
  imports = [
    ./common.nix
    ./boot.nix
    ./console.nix
    ./services.nix
  ];

  # 物理机专属: dash 作为 /bin/sh、桌面权限与实时音频、tty1 自动登录进 niri、硬件用户组
  environment.binsh = "${pkgs.dash}/bin/dash";
  security = {
    polkit.enable = true;
    rtkit.enable = true;
  };
  services.getty.autologinUser = me.userName;
  users.users.${me.userName}.extraGroups = [
    "video"
    "audio"
    "kvm"
  ];
}
