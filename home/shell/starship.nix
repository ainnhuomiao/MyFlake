{ appearance, ... }:
let
  c = appearance.catppuccin;
  h = appearance.toHex;
in
{
  programs.starship = {
    enable = true;
    enableTransience = false;
    settings = {
      add_newline = false;

      # 在 prompt 符号 (❯) 前显示 NixOS 图标 (nf-linux-nixos U+F313),与其同一行
      # 覆盖默认 format:把 $os 挪到 $character 前(line_break 之后),其余顺序与默认一致
      format = "$username$hostname$directory$git_branch$git_state$git_status$nix_shell$cmd_duration$line_break$python$os$character";

      os = {
        disabled = false;
        format = "[$symbol](bold ${h c.mauve}) ";
        symbols = {
          NixOS = "";
        };
      };

      character = {
        success_symbol = "[❯](bold ${h c.mauve})";
        error_symbol = "[❯](bold ${h c.red})";
        vimcmd_symbol = "[❮](bold ${h c.mauve})";
        vimcmd_replace_one_symbol = "[❮](bold ${h c.pink})";
        vimcmd_replace_symbol = "[❮](bold ${h c.pink})";
        vimcmd_visual_symbol = "[❮](bold ${h c.peach})";
      };

      directory = {
        style = h c.lavender;
        truncation_length = 3;
        truncate_to_repo = true;
      };

      git_branch = {
        format = "[$branch]($style) ";
        style = h c.pink;
      };

      git_status = {
        format = "([\\[$all_status$ahead_behind\\]]($style) )";
        style = h c.peach;
        conflicted = "!";
        modified = "~";
        staged = "+";
        untracked = "?";
        deleted = "✗";
        renamed = "↻";
        stashed = "≡";
        ahead = "↑$count";
        behind = "↓$count";
        diverged = "↕";
      };

      cmd_duration = {
        format = "[$duration]($style)";
        style = h c.overlay0;
        min_time = 2000;
      };

      nix_shell = {
        symbol = "󱄅 ";
        format = "[$symbol]($style)";
        style = h c.teal;
      };

      # 只在实际 venv 目录中显示 python 模块;默认的 detect_extensions
      # 会让目录里的 .py 文件触发版本显示
      python = {
        detect_extensions = [ ];
        detect_files = [ ];
      };
    };
  };
}
