{
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ./egpu.nix
    ./tuning.nix
  ];

  networking.hostName = "nixos";

  # stateVersion 记录首次安装时的 NixOS release(当前 stable: 26.05),升级后不要随意改动
  system.stateVersion = "26.05";
}
