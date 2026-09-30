{ appearance, ... }:
let
  cp = appearance.catppuccin;
  h = appearance.toHex;
in
{
  programs.kitty = {
    enable = true;
    font.name = appearance.font.name;
    font.size = 15;
    settings = {
      italic_font = "auto";
      bold_italic_font = "auto";
      mouse_hide_wait = 2;
      cursor_shape = "block";
      url_style = "dotted";
      confirm_os_window_close = 0;
      background_opacity = "0.35";
      dynamic_background_opacity = true;
    };
    extraConfig = ''
      # Catppuccin ${appearance.catppuccinName}，颜色来自 lib/appearance.nix
      foreground           ${h cp.text}
      background           ${h cp.base}
      selection_foreground ${h cp.base}
      selection_background ${h cp.surface2}
      url_color            ${h cp.blue}
      cursor               ${h cp.blue}

      color0  ${h cp.surface1}
      color1  ${h cp.red}
      color2  ${h cp.green}
      color3  ${h cp.yellow}
      color4  ${h cp.blue}
      color5  ${h cp.pink}
      color6  ${h cp.teal}
      color7  ${h cp.subtext1}
      color8  ${h cp.surface2}
      color9  ${h cp.red}
      color10 ${h cp.green}
      color11 ${h cp.yellow}
      color12 ${h cp.blue}
      color13 ${h cp.pink}
      color14 ${h cp.teal}
      color15 ${h cp.subtext0}
    '';
  };
}
