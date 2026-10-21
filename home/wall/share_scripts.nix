{ pkgs, wallpaperDir }:
let
  dms = "${pkgs.dms-shell}/bin/dms";
  stopCycling = ''
    ${pkgs.procps}/bin/pkill -f '/bin/dynamic_wallpaper' || true
  '';
in
{
  wallpaper_random = pkgs.writeShellScriptBin "wallpaper_random" ''
    ${stopCycling}
    exec ${dms} ipc call wallpaper next
  '';
  dynamic_wallpaper = pkgs.writeShellScriptBin "dynamic_wallpaper" ''
    # 不调用 stopCycling，避免 pkill 匹配到当前脚本自身。
    while true; do
      ${dms} ipc call wallpaper next || true
      ${pkgs.coreutils}/bin/sleep 120
    done
  '';
  default_wall = pkgs.writeShellScriptBin "default_wall" ''
    ${stopCycling}
    exec ${dms} ipc call wallpaper set "${wallpaperDir}/default.png"
  '';
}
