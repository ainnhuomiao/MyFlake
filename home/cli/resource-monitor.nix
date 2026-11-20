{ appearance, ... }:
let
  c = appearance.catppuccin;
  h = appearance.toHex;
  colors = {
    main_bg = c.base;
    main_fg = c.text;
    title = c.text;
    hi_fg = c.mauve;
    selected_bg = c.surface1;
    selected_fg = c.text;
    inactive_fg = c.overlay0;
    graph_text = c.subtext0;
    meter_bg = c.surface0;
    proc_misc = c.rosewater;
    cpu_box = c.mauve;
    mem_box = c.green;
    net_box = c.maroon;
    proc_box = c.blue;
    div_line = c.surface1;
    proc_start = c.teal;
    proc_mid = c.sapphire;
    proc_end = c.lavender;
    temp_start = c.green;
    temp_mid = c.yellow;
    temp_end = c.red;
    cpu_start = c.teal;
    cpu_mid = c.sapphire;
    cpu_end = c.lavender;
    free_start = c.green;
    free_mid = c.teal;
    free_end = c.blue;
    cached_start = c.sapphire;
    cached_mid = c.blue;
    cached_end = c.lavender;
    available_start = c.peach;
    available_mid = c.yellow;
    available_end = c.green;
    used_start = c.peach;
    used_mid = c.maroon;
    used_end = c.red;
    download_start = c.peach;
    download_mid = c.maroon;
    download_end = c.red;
    upload_start = c.green;
    upload_mid = c.teal;
    upload_end = c.blue;
  };
in
{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "catppuccin_${appearance.catppuccinVariant}";
      proc_tree = true;
      rounded_corners = false;
    };
  };
  # btop 的打包主题不含 Catppuccin，直接复用 appearance，避免额外下载。
  xdg.configFile."btop/themes/catppuccin_${appearance.catppuccinVariant}.theme".text =
    builtins.concatStringsSep "\n" (
      builtins.attrValues (builtins.mapAttrs (name: color: ''theme[${name}]="${h color}"'') colors)
    )
    + "\n";
}
