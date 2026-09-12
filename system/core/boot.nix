{
  ...
}:
{
  boot = {
    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";
        # GRUB 界面放大 ≈1.5 倍: 内屏原生 2560x1600, 1/1.5 = 1706x1067 非标准模式
        # GRUB 会 fallback, 取 EDID 中最接近的 16:10 标准模式 1680x1050 (≈1.52x)
        gfxmodeEfi = "1680x1050,auto";
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      timeout = 3;
    };
    consoleLogLevel = 0;
    initrd.verbose = false;
  };
}
