{
  pkgs,
  ...
}:
{
  # XWayland 应用统一高清渲染: scale 1.25 下 X11 应用按 120 DPI (96×1.25)
  # 渲染矢量字体, 配合合成器放大后大小正确且清晰。
  # 由 niri 会话 spawn-sh-at-startup 里 xrdb -merge 加载。
  home.file.".Xresources".text = ''
    Xft.dpi: 120
    Xft.antialias: 1
    Xft.hinting: 1
    Xft.hintstyle: hintslight
    Xft.rgba: rgb
  '';
}
