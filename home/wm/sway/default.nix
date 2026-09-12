{
  pkgs,
  inputs,
  lib,
  ...
}:
{
  imports = [ ./config.nix ];

  wayland.windowManager.sway = {
    enable = true;
    # swayfx: 支持背景模糊(毛玻璃),sway 的 drop-in 替代
    package = pkgs.swayfx;
    # swayfx 的 --validate 在无 GPU 的构建沙箱里无法创建 renderer,关闭构建期校验
    checkConfig = false;
    wrapperFeatures.gtk = true;
  };
  home.packages = [
    inputs.hyprpicker.packages.${pkgs.stdenv.hostPlatform.system}.hyprpicker
  ]
  ++ (with pkgs; [
    sway-contrib.grimshot
    pamixer
    swayidle
    (pkgs.writeShellScriptBin "tt" ''
      STATUS=$(swaymsg -t get_inputs | jq -r '.[] | select(.type=="touchpad").libinput.send_events')
      if [[ "$STATUS" == "enabled" ]]; then
          swaymsg input "type:touchpad" events disabled
          notify-send "Touchpad disabled"
      else
          swaymsg input "type:touchpad" events enabled
          notify-send "Touchpad enabled"
      fi
    '')
  ]);

  systemd.user = {
    targets.sway-session.Unit.Wants = [ "xdg-desktop-autostart.target" ];
    # swayidle 只属于 sway 会话: hm 模块默认挂 graphical-session.target,
    # 会话结束时随 wayland 断连退出
    services.swayidle = {
      Unit.PartOf = lib.mkForce [ "sway-session.target" ];
      Install.WantedBy = lib.mkForce [ "sway-session.target" ];
      # hm 模块默认 Restart=always: 会话结束时 swayidle 随 wayland 断连以
      # exit 253 退出, 触发 6 连重启风暴直到 start-limit-hit (每次切换必现),
      # Restart=no: 会话结束时安静退出, 下次 sway-session.target 启动时全新拉起。
      Service.Restart = lib.mkForce "no";
    };
  };

  home = {
    sessionVariables = {
      # 只让 wlroots 探测 Intel 卡:不打开 nvidia 的 DRM 节点,
      # 才能保证 nvidia 模块可热卸载(关坞电源前 modprobe -r)
      WLR_DRM_DEVICES = "/dev/dri/card0";
      # auto: 让 Qt 应用感知合成器 scale (1.25), 强制 1 会导致模糊
      QT_SCALE_FACTOR = "auto";
      # 无 --ozone-platform 参数的 Electron 应用 (vscode/obsidian/feishu/vesktop)
      # 在 sway 下也走 Wayland 原生 (XWayland 非整数 scale 模糊)
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      QT_X11_NO_MITSHM = "1";
      CLUTTER_BACKEND = "wayland";
      XDG_CURRENT_DESKTOP = "sway";
      XDG_SESSION_DESKTOP = "sway";
      XDG_SESSION_TYPE = "wayland";
    };
  };
}
