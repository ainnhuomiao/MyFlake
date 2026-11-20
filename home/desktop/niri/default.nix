{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
{
  imports = [ ./config.nix ];

  wayland.windowManager.niri = {
    enable = true;
    package = osConfig.programs.niri.package;
    checkConfig = true;
    # NixOS 提供会话单位和 portal 路由,HM 只管理配置与 satellite。
    systemd.enable = false;
    portalPackage = null;
    xwaylandSatellitePackage = pkgs.xwayland-satellite;
  };

  services.swayidle = {
    enable = true;
    # niri.service 是 Type=notify: 就绪时已导入 Wayland/IPC 环境。
    systemdTargets = [ "niri.service" ];
    events.before-sleep = "${pkgs.systemd}/bin/loginctl lock-session";
  };
  # 会话结束时不重启,避免 Wayland 断连后 exit 253 的重启风暴。
  systemd.user.services.swayidle.Service.Restart = lib.mkForce "no";

  # 包自带的 XDG 托盘自启既可能早于 Wayland 环境,也会与系统服务重复。
  # 由 NixOS 中绑定 niri.service 的托盘服务统一启动。
  xdg.configFile =
    lib.genAttrs
      [
        "autostart/blueman.desktop"
        "autostart/nm-applet.desktop"
      ]
      (_: {
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Session applet
          Hidden=true
        '';
      });

  home.packages = with pkgs; [
    sway-contrib.grimshot
    pamixer
    # 保留历史命令名。Grimshot 的 anything/window 依赖 swaymsg;
    # niri 原生 UI 支持选区/窗口/输出,按 screenshot-path 保存并复制。
    (writeShellApplication {
      name = "grimshot-savecopy";
      runtimeInputs = [ config.wayland.windowManager.niri.package ];
      text = ''
        exec niri msg action screenshot
      '';
    })
    # 当前 hyprpicker pin 只支持 ext-image-copy-capture,niri 26.04 尚无该协议。
    # 取色使用已支持的 wlr-screencopy;取消选点不改动剪贴板。
    (writeShellApplication {
      name = "color-picker";
      runtimeInputs = [
        grim
        slurp
        imagemagick
        wl-clipboard
      ];
      text = ''
        geometry=$(slurp -p) || exit 0
        [[ -n "$geometry" ]] || exit 0
        color=$(grim -g "$geometry" -t ppm - | magick - -alpha off -depth 8 -format '#%[hex:p{0,0}]' info:)
        printf '%s' "$color" | wl-copy --type text/plain
        printf '%s\n' "$color"
      '';
    })
  ];

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
