{ config, appearance, ... }:
let
  # 稳定路径: Noctalia 会把选中的壁纸路径写进 settings.toml,
  # 用 home symlink (见 home/wall) 而非 store 路径,重建后才不失效
  wallpaperDir = "${config.home.homeDirectory}/${appearance.wallpapersDir}";
in
{
  programs.noctalia = {
    enable = true;
    settings = {
      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Catppuccin";
      };
      # 静态壁纸由 Noctalia 自带壁纸管理器渲染(background layer、
      # 选择器面板 panel-toggle wallpaper、IPC wallpaper-random/set)。
      # 视频壁纸 mpvpaper 独立跑在 bottom layer 盖住这层,见 home/wall
      wallpaper = {
        enabled = true;
        directory = wallpaperDir;
        default = {
          path = "${wallpaperDir}/default.png";
        };
      };
      # 锁屏背景: 捕捉当前桌面(含 mpvpaper 视频壁纸那一帧)做模糊+着色,
      # 复刻旧 swaylock-blur 的模糊壁纸效果
      lockscreen = {
        blurred_desktop = true;
      };
      # 中文界面 (系统 locale 是 en_US, 默认会是英文)
      shell = {
        lang = "zh-Hans";
      };
    };
    # 不启用 systemd service: 用 sway exec 自启, 避免在 wayland socket 就绪前启动
  };
}
