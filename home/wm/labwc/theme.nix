{
  pkgs,
  ...
}:
let
  # Catppuccin Openbox 官方主题(钉版): labwc 主题引擎兼容 openbox,
  # 查找顺序 themes/<name>/labwc/ 优先、回落 themes/<name>/openbox-3/,
  # 本目录只装 openbox-3(即: 不要再放同名 labwc/themerc, 会把它遮住)。
  # 需要 labwc 专属微调时用 ~/.config/labwc/themerc-override 覆盖, 不改此源。
  catppuccinOpenbox = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "openbox";
    rev = "bb1c8662898b156e2b5425d4616bcc8ae4cfeeb2";
    hash = "sha256-56da/tjKvFhBbDF6uBau/KMznWIKeCK6jynbRJRkpTc=";
  };
in
{
  xdg.dataFile."themes/catppuccin-mocha/openbox-3".source =
    "${catppuccinOpenbox}/themes/catppuccin-mocha/openbox-3";
}
