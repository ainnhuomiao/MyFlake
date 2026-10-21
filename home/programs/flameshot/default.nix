{ pkgs, ... }:
{
  services.flameshot = {
    enable = true;
    # niri 截图快捷键使用内置截图；保留编辑器，不启用仅适用于 wlroots 的抓屏后端。
    package = pkgs.flameshot;
    settings = {
      "General" = {
        contrastOpacity = 188;
        showDesktopNotification = false;
        showStartupLaunchMessage = false;
      };
    };
  };
}
