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
      # 禁用 fcitx5-daemon.service: fcitx5 由 sway 会话自行启动 (sway exec),
      # daemon 挂在 graphical-session.target 上会与合成器的 wayland socket
      # 就绪产生竞态 (连接失败 → 输入法热键失效)
      systemd.enable = false;
    };
  };
  home.file = {
    ".config/fcitx5/config".source = ./config;
    ".config/fcitx5/conf/classicui.conf".source = ./classicui.conf;
    ".config/fcitx5/profile".text = import ./profile.nix;
    ".local/share/fcitx5/themes/Catppuccin/theme.conf".text = import ./theme.nix {
      inherit appearance;
    };
  };
}
