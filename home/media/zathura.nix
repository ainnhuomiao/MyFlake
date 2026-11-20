{ appearance, ... }:
let
  c = appearance.catppuccin;
  h = appearance.toHex;
  r = hex: alpha: appearance.toRgba hex alpha;
in
{
  programs.zathura = {
    enable = true;
    extraConfig = ''
      set adjust-open "best-fit"
      set pages-per-row 1
      set scroll-page-aware "true"
      set scroll-full-overlap 0.01
      set scroll-step 50
      set zoom-min 10
      set guioptions ""
      set font "${appearance.font.name} 16"
      set render-loading "false"
      set selection-clipboard clipboard
    ''
    + ''
      set default-fg                ${h c.text}
      set default-bg                ${h c.base}

      set completion-bg             ${h c.surface0}
      set completion-fg             ${h c.text}
      set completion-highlight-bg   ${h c.sapphire}
      set completion-highlight-fg   ${h c.base}
      set completion-group-bg       ${h c.surface0}
      set completion-group-fg       ${h c.blue}

      set statusbar-fg              ${h c.text}
      set statusbar-bg              ${h c.surface0}

      set notification-bg           ${h c.surface0}
      set notification-fg           ${h c.text}
      set notification-error-bg     ${h c.surface0}
      set notification-error-fg     ${h c.red}
      set notification-warning-bg   ${h c.surface0}
      set notification-warning-fg   ${h c.yellow}

      set inputbar-fg               ${h c.text}
      set inputbar-bg               ${h c.surface0}

      set recolor                   "true"
      set recolor-lightcolor        ${h c.base}
      set recolor-darkcolor         ${h c.text}

      set index-fg                  ${h c.text}
      set index-bg                  ${h c.base}
      set index-active-fg           ${h c.base}
      set index-active-bg           ${h c.sapphire}

      set render-loading-bg         ${h c.base}
      set render-loading-fg         ${h c.text}

      set highlight-color           ${r c.mauve "0.5"}
      set highlight-fg              ${r c.sapphire "0.5"}
      set highlight-active-color    ${r c.sapphire "0.5"}
    '';
  };
}
