{
  pkgs,
  appearance,
  ...
}:
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [
        fcitx5-rime
        qt6Packages.fcitx5-chinese-addons
        fcitx5-table-extra
        fcitx5-pinyin-moegirl
        fcitx5-pinyin-zhwiki
      ];
      waylandFrontend = true;
      # 禁用 fcitx5-daemon.service: fcitx5 由 niri 会话自行启动 (spawn-at-startup),
      # daemon 挂在 graphical-session.target 上会与合成器的 wayland socket
      # 就绪产生竞态 (连接失败 → 输入法热键失效)
      systemd.enable = false;
    };
  };
  # niri-session 会启动 XDG autostart;包自带的桌面文件必须屏蔽,
  # 否则会与 spawn-at-startup 同时拉起 fcitx5。
  xdg.configFile."autostart/org.fcitx.Fcitx5.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Fcitx 5
    Hidden=true
  '';
  home.file = {
    ".config/fcitx5/config".source = ./config;
    ".config/fcitx5/conf/classicui.conf".source = ./classicui.conf;
    ".config/fcitx5/profile".text = import ./profile.nix;
    ".local/share/fcitx5/themes/Catppuccin/theme.conf".text = import ./theme.nix {
      inherit appearance;
    };
  };
}
