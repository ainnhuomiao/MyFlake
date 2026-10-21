{ pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixos";

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [
      "quiet"
      # Iris Xe (8086:a7a0) 改用新的 xe 驱动(本内核需 force_probe 才接管);
      # 同时取反阻止 i915 抢占绑定
      "xe.force_probe=a7a0"
      "i915.force_probe=!a7a0"
    ];
  };

  services = {
    fstrim.enable = true;
    fwupd.enable = true;
    upower.enable = true;
    # DMS 的电源模式切换依赖 power-profiles-daemon 的 DBus 接口。
    power-profiles-daemon.enable = true;
  };

  hardware = {
    enableRedistributableFirmware = true;
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    mesa-demos
    libva-utils
  ];
}
