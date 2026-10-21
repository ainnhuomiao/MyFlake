{
  pkgs,
  ...
}:
{
  programs.wshowkeys.enable = true;
  programs = {
    dconf.enable = true;
  };

  programs.niri = {
    enable = true;
    useNautilus = false;
  };

  programs.dms-shell = {
    enable = true;
    systemd.enable = true;
  };

  # DMS 自带 polkit agent、通知和锁屏；不再并行启动 GNOME agent。
  security.pam.services.dankshell = { };
  systemd.user.services.dms = {
    after = [ "niri.service" ];
    partOf = [ "niri.service" ];
    unitConfig.ConditionEnvironment = "NIRI_SOCKET";
  };

  services.blueman.enable = true;

  xdg.portal = {
    enable = true;
    # programs.niri 配置 GNOME ScreenCast + GTK FileChooser；niri 不走 wlr portal。
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # xdg-desktop-portal 在登录早期会被 fake graphical-session 拉起, 彼时
  # XDG_CURRENT_DESKTOP 尚未经 niri-session 导入 user manager。
  # 条件失败后 portal 会延后到首次被调用时(此时会话环境已就绪)再启动。
  systemd.user.services."xdg-desktop-portal".unitConfig.ConditionEnvironment = [
    "XDG_CURRENT_DESKTOP"
  ];

  environment = {
    systemPackages = with pkgs; [
      libnotify
      xeyes
      nemo
      wev
      pulsemixer
      sshpass
      imagemagick
      chafa
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

}
