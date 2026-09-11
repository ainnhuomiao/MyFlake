{
  pkgs,
  me,
  ...
}:
{
  programs.wshowkeys.enable = true;
  programs = {
    dconf.enable = true;
  };

  programs.nm-applet = {
    enable = true;
    indicator = true;
  };

  services.blueman.enable = true;

  xdg.portal = {
    enable = true;
    config = {
      sway = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      };
    };
    wlr = {
      enable = true;
      settings.screencast.chooser_type = "none";
    };
    configPackages = [ pkgs.gnome-session ];
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # xdg-desktop-portal 在登录早期会被 fake graphical-session 拉起, 彼时
  # XDG_CURRENT_DESKTOP 尚未经 dbus-update-activation-environment 导入
  # user manager → portal 进程缺该变量 → 匹配不到 sway-portals.conf →
  # 不导出 Screenshot/ScreenCast 接口 → flameshot 等截图应用 30s 超时无窗口。
  # 条件失败后 portal 会延后到首次被调用时(此时会话环境已就绪)再启动。
  systemd.user.services."xdg-desktop-portal".unitConfig.ConditionEnvironment = [
    "XDG_CURRENT_DESKTOP"
  ];

  environment = {
    systemPackages = with pkgs; [
      libnotify
      wlr-randr
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
      vscode
      blender
      s-search
      gparted
      brightnessctl
      # XWayland 高清渲染 (Xft.dpi 加载工具)
      xrdb
    ];
    variables.NIXOS_OZONE_WL = "1";
  };

  services = {
    dbus.packages = [ pkgs.gcr ];
    gvfs.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
  };

  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
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
