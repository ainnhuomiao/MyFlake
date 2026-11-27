{ inputs, pkgs, ... }:
let
  zen-pkgs = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = with pkgs; [
    bilibili
    google-chrome
    microsoft-edge
    thunderbird-bin
    gdu
    openssl
    kooha
    rayburst
    obsidian
    splayer-next
    wl-screenrec
    wl-clipboard
    zen-pkgs.zen-browser
  ];
}
