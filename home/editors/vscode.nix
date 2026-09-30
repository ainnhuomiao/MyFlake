{ pkgs, appearance, ... }:
let
  # Not yet packaged in nixpkgs; built from the VS Code Marketplace.
  kimi-code = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "kimi-code";
      publisher = "moonshot-ai";
      version = "0.8.1";
      hash = "sha256-vEoh0IGNljbdMaVLNrPNDSmI6OhitJmdsFSbnheAw8g=";
    };
    meta = {
      description = "Kimi Code for VS Code";
      license = pkgs.lib.licenses.mit;
    };
  };
in
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
        pkgs.vscode-extensions.illixion.vscode-vibrancy-continued
        kimi-code
      ];
      userSettings = {
        "workbench.colorTheme" = "Catppuccin ${appearance.catppuccinName}";
        "catppuccin.accentColor" = "mauve";
        "catppuccin.boldKeywords" = true;
        "catppuccin.italicComments" = true;
        "catppuccin.italicKeywords" = true;
        "catppuccin.workbenchMode" = "default";
        "catppuccin.bracketMode" = "rainbow";
        "catppuccin.extraBordersEnabled" = false;
        "editor.semanticHighlighting.enabled" = true;
        "terminal.integrated.minimumContrastRatio" = 1;
        # Vibrancy Continued
        "vscode_vibrancy.theme" = "Catppuccin ${appearance.catppuccinName}";
        "vscode_vibrancy.opacity" = 0.8;
        # Vibrancy renders the terminal translucent only with the DOM renderer.
        "terminal.integrated.gpuAcceleration" = "off";
        "window.titleBarStyle" = "custom";
        "chat.disableAIFeatures" = true;
        "chat.commandCenter.enabled" = false;
      };
    };
  };
}
