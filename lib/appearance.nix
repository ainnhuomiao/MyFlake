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
  # Noctalia 壁纸管理器浏览该稳定路径 —— 它会把选中的壁纸绝对路径持久化到
  # settings.toml,而 nix store 路径每次重建都会变,持久化后必然失效。
  wallpapersDir = "Pictures/wallpapers";

  # 视频壁纸目录(同上): Noctalia 官方 mpvpaper 插件把分配的视频路径持久化到
  # 自己的 state(assignments.json),同样不能是 store 路径。
  videosDir = "Videos/wallpapers";

  font = {
    name = "Maple Mono NF CN";
    size = 12;
  };

  palettes = {
    tokyoNight = {
      bg = "24283b";
      fg = "c0caf5";
      fg_dim = "a9b1d6";
      comment = "565f89";
      sel_bg = "292e42";
      blue = "7aa2f7";
      cyan = "7dcfff";
      purple = "bb9af7";
      green = "9ece6a";
      teal = "73daca";
      red = "f7768e";
      orange = "ff9e64";
      yellow = "e0af68";
    };

    catppuccinMocha = {
      base = "1e1e2e";
      surface0 = "313244";
      overlay0 = "6c7086";
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

    nord = {
      # Polar Night
      nord0 = "2e3440";
      nord1 = "3b4252";
      nord2 = "434c5e";
      nord3 = "4c566a";
      # Snow Storm
      nord4 = "d8dee9";
      nord5 = "e5e9f0";
      nord6 = "eceff4";
      # Frost
      nord7 = "8fbcbb";
      nord8 = "88c0d0";
      nord9 = "81a1c1";
      nord10 = "5e81ac";
      # Aurora
      nord11 = "bf616a";
      nord12 = "d08770";
      nord13 = "ebcb8b";
      nord14 = "a3be8c";
      nord15 = "b48ead";
    };
  };

  # catppuccin 四主题(kitty 16 色语义, 官方映射)。切换: 改 catppuccinVariant
  catppuccinVariant = "mocha";
  catppuccin = {
    latte = {
      bg = "eff1f5";
      fg = "4c4f69";
      color0 = "bcc0cc";
      color1 = "d20f39";
      color2 = "40a02b";
      color3 = "df8e1d";
      color4 = "1e66f5";
      color5 = "ea76cb";
      color6 = "179299";
      color7 = "5c5f77";
      color8 = "acb0be";
      color9 = "d20f39";
      color10 = "40a02b";
      color11 = "df8e1d";
      color12 = "1e66f5";
      color13 = "ea76cb";
      color14 = "179299";
      color15 = "6c6f85";
    };
    frappe = {
      bg = "303446";
      fg = "c6d0f5";
      color0 = "51576d";
      color1 = "e78284";
      color2 = "a6d189";
      color3 = "e5c890";
      color4 = "8caaee";
      color5 = "f4b8e4";
      color6 = "81c8be";
      color7 = "b5bfe2";
      color8 = "626880";
      color9 = "e78284";
      color10 = "a6d189";
      color11 = "e5c890";
      color12 = "8caaee";
      color13 = "f4b8e4";
      color14 = "81c8be";
      color15 = "a5adce";
    };
    macchiato = {
      bg = "24273a";
      fg = "cad3f5";
      color0 = "494d64";
      color1 = "ed8796";
      color2 = "a6da95";
      color3 = "eed49f";
      color4 = "8aadf4";
      color5 = "f5bde6";
      color6 = "8bd5ca";
      color7 = "b8c0e0";
      color8 = "5b6078";
      color9 = "ed8796";
      color10 = "a6da95";
      color11 = "eed49f";
      color12 = "8aadf4";
      color13 = "f5bde6";
      color14 = "8bd5ca";
      color15 = "a5adcb";
    };
    mocha = {
      bg = "1e1e2e";
      fg = "cdd6f4";
      color0 = "45475a";
      color1 = "f38ba8";
      color2 = "a6e3a1";
      color3 = "f9e2af";
      color4 = "89b4fa";
      color5 = "f5c2e7";
      color6 = "94e2d5";
      color7 = "bac2de";
      color8 = "585b70";
      color9 = "f38ba8";
      color10 = "a6e3a1";
      color11 = "f9e2af";
      color12 = "89b4fa";
      color13 = "f5c2e7";
      color14 = "94e2d5";
      color15 = "a6adc8";
    };
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
