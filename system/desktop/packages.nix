{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    libnotify
    wlprop
    xeyes
    nemo
    wev
    pulsemixer
    sshpass
    imagemagick
    chafa
    grim
    slurp
    gparted
    brightnessctl
    # XWayland 高清渲染 (Xft.dpi 加载工具)
    xrdb
  ];
}
