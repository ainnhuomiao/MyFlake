let
  hexDigit =
    let
      table = {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
        "A" = 10;
        "B" = 11;
        "C" = 12;
        "D" = 13;
        "E" = 14;
        "F" = 15;
      };
    in
    c: table.${c} or (throw "invalid hex digit: ${c}");

  hexByteToInt =
    s: (hexDigit (builtins.substring 0 1 s)) * 16 + (hexDigit (builtins.substring 1 1 s));
in
{
  # 壁纸目录(home 相对路径): home/wall 在此建 symlink 指向 assets/wallpapers,
  # DMS 把选中的壁纸绝对路径写入 session.json，稳定路径可跨重建保留。
  wallpapersDir = "Pictures/wallpapers";

  # 保留视频资源入口；dms-niri 分支本轮只迁移静态壁纸。
  videosDir = "Videos/wallpapers";

  font = {
    name = "Maple Mono NF CN";
    size = 12;
  };

  # 单一配色入口：所有桌面、终端与编辑器共用 Catppuccin Mocha。
  catppuccinVariant = "mocha";
  catppuccinName = "Mocha";
  catppuccin = {
    crust = "11111b";
    mantle = "181825";
    base = "1e1e2e";
    surface0 = "313244";
    surface1 = "45475a";
    surface2 = "585b70";
    overlay0 = "6c7086";
    overlay1 = "7f849c";
    overlay2 = "9399b2";
    subtext0 = "a6adc8";
    subtext1 = "bac2de";
    text = "cdd6f4";
    lavender = "b4befe";
    blue = "89b4fa";
    sapphire = "74c7ec";
    sky = "89dceb";
    teal = "94e2d5";
    green = "a6e3a1";
    yellow = "f9e2af";
    peach = "fab387";
    maroon = "eba0ac";
    red = "f38ba8";
    mauve = "cba6f7";
    pink = "f5c2e7";
    flamingo = "f2cdcd";
    rosewater = "f5e0dc";
  };

  # hex string → "#rrggbb"  (starship, fish, kitty, etc.)
  toHex = hex: "#${hex}";

  # hex string + alpha → "rgba(r,g,b,a)"  (zathura, GTK)
  toRgba =
    hex: alpha:
    let
      r = hexByteToInt (builtins.substring 0 2 hex);
      g = hexByteToInt (builtins.substring 2 2 hex);
      b = hexByteToInt (builtins.substring 4 2 hex);
    in
    "rgba(${toString r},${toString g},${toString b},${alpha})";

  # hex string → "r,g,b"  (kmscon palette 等十进制 RGB 消费者)
  toRgb =
    hex:
    let
      r = hexByteToInt (builtins.substring 0 2 hex);
      g = hexByteToInt (builtins.substring 2 2 hex);
      b = hexByteToInt (builtins.substring 4 2 hex);
    in
    "${toString r},${toString g},${toString b}";

  # hex string → "38;2;r;g;b"  (EZA_COLORS, any ANSI true-color consumer)
  toAnsi =
    hex:
    let
      r = hexByteToInt (builtins.substring 0 2 hex);
      g = hexByteToInt (builtins.substring 2 2 hex);
      b = hexByteToInt (builtins.substring 4 2 hex);
    in
    "38;2;${toString r};${toString g};${toString b}";

}
