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

  environment = {
    systemPackages = with pkgs; [
      libnotify
      wf-recorder
      wlprop
      xeyes
      nemo
      wev
      pulsemixer
      sshpass
      imagemagick
      chafa
      grim
      slurp
      satty
      linux-wifi-hotspot
      scrcpy
      gource
      blender
      gparted
      brightnessctl
      # XWayland 高清渲染 (Xft.dpi 加载工具)
      xrdb
    ];
    variables.NIXOS_OZONE_WL = "1";
  };

  services = {
    # nixpkgs 2026-09-03 移除了无 ABI 后缀的 `gcr`,需显式指定 ABI;
    # gcr_3 = 原 gcr 3.x(GTK3) 线,与旧 `pkgs.gcr` 行为一致(上游 nm-applet 模块同样用它)
    dbus.packages = [ pkgs.gcr_3 ];
    gvfs.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
  };

  systemd.user.services = portalServices // {
    # 不依赖 graphical-session.target 的历史状态,等待 niri 的 Type=notify。
    # 对应 XDG 自启动文件在 HM 屏蔽,只保留这一份实例。
    nm-applet = {
      wantedBy = lib.mkForce [ "niri.service" ];
      partOf = lib.mkForce [ "niri.service" ];
      after = lib.mkForce [ "niri.service" ];
      unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    blueman-applet = {
      description = "Blueman applet for the niri session";
      wantedBy = [ "niri.service" ];
      partOf = [ "niri.service" ];
      after = [ "niri.service" ];
      unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
      # 沿用 blueman 包的 Type=dbus/ExecStart,这里只补会话依赖。
    };
    polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "niri.service" ];
      partOf = [ "niri.service" ];
      after = [ "niri.service" ];
      unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };
}
