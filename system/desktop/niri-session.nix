{
  lib,
  pkgs,
  ...
}:
let
  # graphical-session.target 可能早于 niri 存在,仅检查 Wayland 变量也会
  # 接受上一会话的旧环境。portal 必须等 niri 就绪并随其退出,避免旧进程
  # 留到下一次登录后只导出 GTK 接口、缺失 Screenshot/ScreenCast。
  portalServices =
    lib.genAttrs
      [
        "xdg-desktop-portal"
        "xdg-desktop-portal-gtk"
        "xdg-desktop-portal-gnome"
        "xdg-desktop-portal-wlr"
      ]
      (_: {
        partOf = [ "niri.service" ];
        after = [ "niri.service" ];
        unitConfig.ConditionEnvironment = [
          "XDG_CURRENT_DESKTOP=niri"
          "WAYLAND_DISPLAY"
          "NIRI_SOCKET"
        ];
      });

  # 同用户管理器被另一 VT 上的 Hyprland 污染后,WAYLAND_DISPLAY / DISPLAY /
  # XDG_CURRENT_DESKTOP 可能指向已死的 socket。托盘 applet 在 rebuild 重启时
  # 会继承这份坏环境: blueman(Type=dbus) 直接让 nh activation 失败。
  # 从仍正确的 NIRI_SOCKET 重推 Wayland 显示,并强制走 Wayland GDK。
  niriGuiWrapper =
    name: command:
    pkgs.writeShellScript name ''
      set -eu
      if [ -n "''${NIRI_SOCKET:-}" ]; then
        sock_base="''${NIRI_SOCKET##*/}"
        case "$sock_base" in
          niri.wayland-*)
            disp="''${sock_base#niri.}"
            disp="''${disp%%.*}"
            if [ -S "''${XDG_RUNTIME_DIR}/$disp" ]; then
              export WAYLAND_DISPLAY="$disp"
            fi
            ;;
        esac
      fi
      export XDG_CURRENT_DESKTOP=niri
      export GDK_BACKEND=wayland
      if [ -S /tmp/.X11-unix/X0 ]; then
        export DISPLAY=:0
      else
        unset DISPLAY || true
      fi
      exec ${command}
    '';
in
{
  programs.wshowkeys.enable = true;
  programs = {
    dconf.enable = true;
    niri = {
      enable = true;
      # 继续使用 Nemo,文件选择交给 GTK portal。
      useNautilus = false;
    };
  };

  programs.nm-applet = {
    enable = true;
    indicator = true;
  };

  services.blueman.enable = true;

  xdg.portal = {
    enable = true;
    config = {
      niri = {
        # 其他接口沿用 NixOS niri 模块的 gnome/gtk 默认路由。
        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      };
    };
    wlr = {
      enable = true;
    };
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.variables.NIXOS_OZONE_WL = "1";

  services = {
    # nixpkgs 2026-09-03 移除了无 ABI 后缀的 `gcr`,需显式指定 ABI;
    # gcr_3 = 原 gcr 3.x(GTK3) 线,与旧 `pkgs.gcr` 行为一致(上游 nm-applet 模块同样用它)
    dbus.packages = [ pkgs.gcr_3 ];
    gvfs.enable = true;
  };

  systemd.user.services = portalServices // {
    # 不依赖 graphical-session.target 的历史状态,等待 niri 的 Type=notify。
    # 对应 XDG 自启动文件在 HM 屏蔽,只保留这一份实例。
    nm-applet = {
      wantedBy = lib.mkForce [ "niri.service" ];
      partOf = lib.mkForce [ "niri.service" ];
      after = lib.mkForce [ "niri.service" ];
      unitConfig.ConditionEnvironment = [
        "NIRI_SOCKET"
        "WAYLAND_DISPLAY"
      ];
      serviceConfig.ExecStart = lib.mkForce (
        niriGuiWrapper "nm-applet-niri" "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator"
      );
    };
    blueman-applet = {
      description = "Blueman applet for the niri session";
      wantedBy = [ "niri.service" ];
      partOf = [ "niri.service" ];
      after = [ "niri.service" ];
      unitConfig.ConditionEnvironment = [
        "NIRI_SOCKET"
        "WAYLAND_DISPLAY"
      ];
      # 保留上游 Type=dbus/BusName;只替换 ExecStart,避免坏的用户管理器环境。
      serviceConfig.ExecStart = lib.mkForce (
        niriGuiWrapper "blueman-applet-niri" "${pkgs.blueman}/bin/blueman-applet"
      );
    };
    polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "niri.service" ];
      partOf = [ "niri.service" ];
      after = [ "niri.service" ];
      unitConfig.ConditionEnvironment = [
        "NIRI_SOCKET"
        "WAYLAND_DISPLAY"
      ];
      serviceConfig = {
        Type = "simple";
        ExecStart = niriGuiWrapper "polkit-gnome-niri" "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };
}
