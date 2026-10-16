{
  pkgs,
  inputs,
  lib,
  ...
}:
{
  imports = [
    ./config.nix
    ./theme.nix
  ];

  wayland.windowManager.labwc = {
    enable = true;
    # 会话集成: autostart 里导入 WAYLAND_DISPLAY/XDG_CURRENT_DESKTOP 到
    # systemd/dbus 并拉起 labwc-session.target(用户服务的挂载点)
    systemd.enable = true;
    # rc.xml 内容见 config.nix; 组合键暂用 labwc 默认键, 待统一重写
  };

  services.swayidle = {
    enable = true;
    events = {
      "before-sleep" = "${pkgs.systemd}/bin/loginctl lock-session";
    };
  };

  home.packages = [
    inputs.hyprpicker.packages.${pkgs.stdenv.hostPlatform.system}.hyprpicker
  ]
  ++ (with pkgs; [
    # grim 系走 wlr-screencopy, labwc 同为 wlroots, 原样可用
    sway-contrib.grimshot
    pamixer
    # 交互截图存 ~/Pictures(带时间戳): labwc 的 Execute 不走 shell,
    # 旧 sway 内联的 $(date …) 必须落成脚本
    (pkgs.writeShellScriptBin "grimshot-savecopy" ''
      exec ${pkgs.sway-contrib.grimshot}/bin/grimshot --notify savecopy anything \
        "$HOME/Pictures/$(date '+%Y-%m-%dT%H_%M_%S').png"
    '')
  ]);

  systemd.user = {
    # swayidle 只属于合成器会话: hm 模块默认挂 graphical-session.target,
    # 会话结束时随 wayland 断连退出
    services.swayidle = {
      Unit.PartOf = lib.mkForce [ "labwc-session.target" ];
      Install.WantedBy = lib.mkForce [ "labwc-session.target" ];
      # hm 模块默认 Restart=always: 会话结束时 swayidle 随 wayland 断连以
      # exit 253 退出, 触发 6 连重启风暴直到 start-limit-hit (每次切换必现),
      # Restart=no: 会话结束时安静退出, 下次会话启动时全新拉起。
      Service.Restart = lib.mkForce "no";
    };
  };

  home = {
    sessionVariables = {
      # 只让 wlroots 探测 Intel 卡:不打开 nvidia 的 DRM 节点,
      # 才能保证 nvidia 模块可热卸载(关坞电源前 modprobe -r)
      WLR_DRM_DEVICES = "/dev/dri/card0";
      # 无 --ozone-platform 参数的 Electron 应用 (vscode/obsidian/feishu/vesktop)
      # 走 Wayland 原生 (XWayland 非整数 scale 模糊)
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      QT_X11_NO_MITSHM = "1";
      CLUTTER_BACKEND = "wayland";
    };
  };
}
