{ pkgs, ... }:
{
  services.flameshot = {
    enable = true;
    package = pkgs.flameshot.override { enableWlrSupport = true; };
    settings = {
      "General" = {
        contrastOpacity = 188;
        showDesktopNotification = false;
        showStartupLaunchMessage = false;
      };
    };
  };
}
