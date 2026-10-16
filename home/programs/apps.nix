{ inputs, pkgs, ... }:
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
    imv
    swayimg
    kooha
    rayburst
    obsidian
    splayer-next
    kdePackages.kdenlive
    wl-screenrec
    wl-clipboard
    wpsoffice-cn
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
