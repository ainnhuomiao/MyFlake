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
    hmcl
    imv
    swayimg
    kooha
    motrix-next
    obsidian
    splayer-next
    kdePackages.kdenlive
    wl-screenrec
    wpsoffice-cn
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
