{
  pkgs,
  noctalia,
  wallpaperDir,
}:
let
  pluginService = "noctalia/mpvpaper:service";
  # 关掉视频壁纸:清空插件的视频分配(它会让 Noctalia 的壁纸层重新显形)
  stopVideo = "${noctalia} msg plugin ${pluginService} all clear-all >/dev/null 2>&1 || true";
  # 切回静态壁纸模式:停视频、停轮换、恢复 swayfx blur。
  # 静态壁纸本体由 Noctalia 渲染,不需要任何壁纸守护进程。
  ensureStatic = ''
    ${pkgs.procps}/bin/pkill -f '/bin/dynamic_wallpaper' || true
    ${stopVideo}
    ${pkgs.sway}/bin/swaymsg blur enable >/dev/null 2>&1 || true
  '';
in
{
  wallpaper_random = pkgs.writeShellScriptBin "wallpaper_random" ''
    ${ensureStatic}
    resp=$(${noctalia} msg wallpaper-random 2>&1) || true
    [[ "$resp" == error:* ]] && ${pkgs.libnotify}/bin/notify-send "Wallpaper" "$resp"
  '';
  dynamic_wallpaper = pkgs.writeShellScriptBin "dynamic_wallpaper" ''
    # 注意:这里不能复用 ensureStatic——它的 pkill 会匹配到本脚本自身的 bash 进程
    # (cmdline 为 bash .../bin/dynamic_wallpaper),导致启动即自杀
    ${stopVideo}
    ${pkgs.sway}/bin/swaymsg blur enable >/dev/null 2>&1 || true
    while true; do
      ${noctalia} msg wallpaper-random >/dev/null 2>&1 || true
      ${pkgs.coreutils}/bin/sleep 120
    done
  '';
  default_wall = pkgs.writeShellScriptBin "default_wall" ''
    ${ensureStatic}
    resp=$(${noctalia} msg wallpaper-set "${wallpaperDir}/default.png" 2>&1) || true
    [[ "$resp" == error:* ]] && ${pkgs.libnotify}/bin/notify-send "Wallpaper" "$resp"
  '';
  # 打开视频壁纸选择器面板(选取视频、暂停/继续、清除)
  video_wallpaper = pkgs.writeShellScriptBin "video_wallpaper" ''
    ${noctalia} msg panel-toggle noctalia/mpvpaper:picker
  '';
  # 清除视频壁纸,回到静态壁纸
  video_wallpaper_clear = pkgs.writeShellScriptBin "video_wallpaper_clear" ''
    ${noctalia} msg plugin ${pluginService} all clear-all >/dev/null 2>&1 || true
    ${pkgs.sway}/bin/swaymsg blur enable >/dev/null 2>&1 || true
    ${pkgs.libnotify}/bin/notify-send "Wallpaper" "已清除视频壁纸"
  '';
}
