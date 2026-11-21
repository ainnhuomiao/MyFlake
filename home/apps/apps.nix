{ inputs, pkgs, ... }:
let
  zen-pkgs = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = with pkgs; [
    bili_tui
    bilibili
    piliplus
    google-chrome
    dbeaver-bin
    discord
    microsoft-edge
    thunderbird-bin
    gdu
    openssl
    imv
    swayimg
    kooha
    kimi-code-desktop
    rayburst
    obsidian
    splayer-next
    kdePackages.kdenlive
    wl-screenrec
    wl-clipboard
    wpsoffice-cn
    zen-pkgs.zen-browser
  ];
}
