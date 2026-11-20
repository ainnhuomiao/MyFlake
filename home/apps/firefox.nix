{ pkgs, ... }:
{
  home.sessionVariables = {
    BROWSER = "firefox";
  };

  programs.firefox = {
    enable = true;
    package = pkgs.firefox-bin;
    configPath = ".mozilla/firefox";
  };
}
