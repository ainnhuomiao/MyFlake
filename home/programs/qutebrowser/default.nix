{ pkgs, appearance, ... }:
let
  # catppuccin/qutebrowser 主题(含 __init__.py + setup.py, import catppuccin 即用)
  catppuccinTheme = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "qutebrowser";
    rev = "808adc3d7d5be6fc573d6be6e9c888cb96b5d6e6";
    hash = "sha256-FmxrgpFlp+cMUdCx5HHIiLMGWML23p+pfxTKT/X0UME=";
  };
in
{
  programs.qutebrowser = {
    enable = true;

    searchEngines = {
      DEFAULT = "https://www.bing.com/search?q={}";
      g = "https://www.google.com/search?q={}";
      b = "https://www.bing.com/search?q={}";
      w = "https://en.wikipedia.org/wiki/Special:Search?search={}";
      n = "https://search.nixos.org/packages?channel=unstable&query={}";
      gh = "https://github.com/search?q={}";
    };

    settings = {
      # 单一 Mocha 暗色主题，与桌面及编辑器保持一致。
      colors.webpage.darkmode.enabled = true;
      fonts.default_family = appearance.font.name;
      fonts.default_size = "${toString appearance.font.size}pt";
      url.start_pages = "https://www.bing.com";
    };

    # catppuccin 主题: flavor 跟随 appearance.catppuccinVariant
    extraConfig = ''
      import catppuccin

      catppuccin.setup(c, '${appearance.catppuccinVariant}', True)
    '';
  };

  xdg.configFile."qutebrowser/catppuccin".source = catppuccinTheme;
}
