{
  pkgs,
  noctalia,
  wallpaperDir,
}:
let
  videoDirectory = ../../assets/videos;
  # 切回静态壁纸模式:停 mpvpaper(它跑在 bottom layer,会盖住 Noctalia 的
  # background 壁纸层)、停轮换、恢复 swayfx blur。静态壁纸本体由 Noctalia
  # 自己渲染(见 home/programs/noctalia),不再需要任何壁纸守护进程。
  ensureStatic = ''
    ${pkgs.procps}/bin/pkill -f '/bin/dynamic_wallpaper' || true
    ${pkgs.systemd}/bin/systemctl --user stop video-wall
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
    ${pkgs.systemd}/bin/systemctl --user stop video-wall || true
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
  # 视频/静态壁纸切换(Mod+Ctrl+v)
  video_wallpaper = pkgs.writeShellScriptBin "video_wallpaper" ''
    if ${pkgs.systemd}/bin/systemctl --user is-active --quiet video-wall; then
      # 视频模式 → 恢复静态:Noctalia 壁纸层一直在画,停掉 mpvpaper 即显形
      ${pkgs.systemd}/bin/systemctl --user stop video-wall
      ${pkgs.sway}/bin/swaymsg blur enable >/dev/null 2>&1 || true
      ${pkgs.libnotify}/bin/notify-send "Wallpaper" "已切换为静态壁纸"
    else
      # 静态模式 → 视频(mpvpaper)
      ${pkgs.procps}/bin/pkill -f '/bin/dynamic_wallpaper' || true
      # sway 在无 bg 配置时兜底拉起的裸 swaybg,与 mpvpaper 抢 background layer
      ${pkgs.procps}/bin/pkill -f '/bin/swaybg' || true
      ${pkgs.sway}/bin/swaymsg blur disable >/dev/null 2>&1 || true
      ${pkgs.systemd}/bin/systemctl --user start video-wall
      ${pkgs.libnotify}/bin/notify-send "Wallpaper" "已切换为视频壁纸"
    fi
  '';
  # mpvpaper 服务入口:assets/videos 下全部视频写入 m3u 播放列表(随机顺序),
  # 单个视频循环播放不自动切换,由 video_wallpaper_next 手动切换
  # 注意:mpvpaper 1.8 只接受一个文件参数(main.c: video_path=argv[optind+1]),
  # 多视频必须走 --playlist=;且 main.c 会截掉 -o 里 --playlist= 到行尾的内容,
  # 所以 --playlist= 必须放在 -o 的最后
  # -l bottom:Noctalia 自带壁纸管理器占用 background layer,视频放在 bottom layer
  # 才能稳定盖住它(同层两张 surface 谁在上取决于 map 顺序,不可靠)
  video_wallpaper_play = pkgs.writeShellScriptBin "video_wallpaper_play" ''
    mapfile -t videos < <(${pkgs.findutils}/bin/find "${videoDirectory}" -type f \
      \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) \
      -print0 | ${pkgs.coreutils}/bin/sort -z | ${pkgs.findutils}/bin/xargs -0 -r -n1 printf '%s\n')
    if [[ ''${#videos[@]} -eq 0 ]]; then
      ${pkgs.libnotify}/bin/notify-send "Wallpaper" "No videos found in assets/videos"
      exit 1
    fi
    { echo '#EXTM3U'; printf '%s\n' "''${videos[@]}"; } > /tmp/mpvpaper-playlist.m3u
    # no-config:用户 mpv 配置的 vo=gpu + profile=gpu-hq 与 mpvpaper 的 libmpv 渲染冲突,
    # 实测 4K60 视频丢帧 400+/播放速度 ~0.1x;no-config 后接近实时、丢帧个位数
    # loop-file=inf:当前视频无限循环不自动切;loop=inf:playlist-next 到尾后绕回第一个
    # 登录自动启动时也会撞上 sway 兜底拉起的裸 swaybg,先清掉再占位
    ${pkgs.procps}/bin/pkill -f '/bin/swaybg' || true
    exec ${pkgs.mpvpaper}/bin/mpvpaper -l bottom \
      -o "no-config no-audio --shuffle --loop=inf --loop-file=inf --hwdec=vaapi --input-ipc-server=/tmp/mpvpaper.sock --playlist=/tmp/mpvpaper-playlist.m3u" \
      ALL
  '';
  # 手动切换下一个视频壁纸(mpv JSON IPC;未开视频模式时静默无操作)
  # 注意:现代 mpv 的 input-ipc-server 是 JSON 协议,老式 get_property 文本命令无回复;
  # playlist-next 到末尾报 error 不绕回,故用 playlist-play-index 按模数索引切换
  video_wallpaper_next = pkgs.writeShellScriptBin "video_wallpaper_next" ''
    get_prop() {
      { echo "{\"command\": [\"get_property\", \"$1\"]}"; sleep 0.2; } | \
        ${pkgs.socat}/bin/socat - /tmp/mpvpaper.sock 2>/dev/null | \
        ${pkgs.jq}/bin/jq -r '.data // empty' 2>/dev/null
    }
    COUNT=$(get_prop playlist-count)
    POS=$(get_prop playlist-pos)
    if [[ -n "$COUNT" && "$COUNT" -gt 0 && -n "$POS" && "$POS" -ge 0 ]]; then
      NAME=$(get_prop filename)
      NEXT=$(( (POS + 1) % COUNT ))
      echo "{\"command\": [\"playlist-play-index\", $NEXT]}" | ${pkgs.socat}/bin/socat - /tmp/mpvpaper.sock >/dev/null 2>&1 || true
      NEW="$NAME"
      for i in 1 2 3 4 5; do
        NEW=$(get_prop filename)
        [[ -n "$NEW" && "$NEW" != "$NAME" ]] && break
        ${pkgs.coreutils}/bin/sleep 0.3
      done
      if [[ -n "$NEW" && "$NEW" != "$NAME" ]]; then
        ${pkgs.libnotify}/bin/notify-send "Wallpaper" "视频壁纸: $NEW"
      fi
    fi
  '';
}
