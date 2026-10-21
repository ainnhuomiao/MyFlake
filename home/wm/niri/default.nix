{
  pkgs,
  lib,
  appearance,
  ...
}:
{
  # 会话、portal 和 systemd 集成由 NixOS programs.niri 提供；HM 管理用户 KDL。
  xdg.configFile."niri/config.kdl".text = import ./config.nix { inherit lib pkgs appearance; };

  home.packages = [ pkgs.xwayland-satellite ];

  home.sessionVariables = {
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    SDL_VIDEODRIVER = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_X11_NO_MITSHM = "1";
    CLUTTER_BACKEND = "wayland";
  };
}
