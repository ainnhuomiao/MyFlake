{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    mutableExtensionsDir = true;
    profiles.default = {
      extensions = [
        pkgs.vscode-extensions.catppuccin.catppuccin-vsc
        pkgs.vscode-extensions.jnoortheen.nix-ide
        pkgs.vscode-extensions.arrterian.nix-env-selector
        pkgs.vscode-extensions.mkhl.direnv
      ];
      userSettings = {
        "workbench.colorTheme" = "Catppuccin Frappé";
        "catppuccin.accentColor" = "mauve";
        "catppuccin.boldKeywords" = true;
        "catppuccin.italicComments" = true;
        "catppuccin.italicKeywords" = true;
        "catppuccin.workbenchMode" = "default";
        "catppuccin.bracketMode" = "rainbow";
        "catppuccin.extraBordersEnabled" = false;
        "editor.semanticHighlighting.enabled" = true;
        "terminal.integrated.minimumContrastRatio" = 1;
        "window.titleBarStyle" = "custom";
        "chat.disableAIFeatures" = true;
        "chat.commandCenter.enabled" = false;
      };
    };
  };
}
