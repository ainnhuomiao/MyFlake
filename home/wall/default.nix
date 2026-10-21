{
  pkgs,
  config,
  appearance,
  ...
}:
let
  wallpaperDir = "${config.home.homeDirectory}/${appearance.wallpapersDir}";
  scripts = import ./share_scripts.nix { inherit pkgs wallpaperDir; };
in
{
  # DMS 原生渲染静态壁纸；视频资源保留，后续另行迁移播放功能。
  home.file."${appearance.wallpapersDir}".source = ../../assets/wallpapers;
  home.file."${appearance.videosDir}".source = ../../assets/videos;

  home.packages = with scripts; [
    wallpaper_random
    dynamic_wallpaper
    default_wall
  ];
}
