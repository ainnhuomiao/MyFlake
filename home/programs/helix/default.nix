{ pkgs, appearance, ... }:
{
  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "catppuccin_${appearance.catppuccinVariant}";
      editor = {
        line-number = "relative";
        mouse = false;
        bufferline = "always";
        color-modes = true;
        true-color = true;
        cursorline = true;
        cursor-shape = {
          insert = "bar";
        };
        indent-guides = {
          render = true;
          character = "▎";
        };
        soft-wrap.enable = true;
        statusline = {
          left = [
            "mode"
            "spinner"
            "file-name"
          ];
          right = [
            "diagnostics"
            "selections"
            "position"
            "file-encoding"
          ];
        };
        whitespace = {
          render.space = "all";
          characters = {
            space = "·";
            nbsp = "⍽";
            tab = "→";
            newline = "↵";
          };
        };
      };
    };
    languages = {
      language = [
        {
          name = "nix";
          auto-format = true;
          formatter.command = "${pkgs.nixfmt}/bin/nixfmt";
        }
      ];
    };
    ignores = [
      ".direnv"
      "result"
    ];
  };
}
