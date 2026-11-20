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
        # generation 是 gcroot 永不自动清理, 内核+initrd 每个约百 MB, 限制数量防 ESP 塞满
        configurationLimit = 15;
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      timeout = 3;
    };
    consoleLogLevel = 0;
  };
}
