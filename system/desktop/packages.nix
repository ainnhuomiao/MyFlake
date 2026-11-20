{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    libnotify
    wf-recorder
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
    satty
    linux-wifi-hotspot
    scrcpy
    gource
    blender
    gparted
    brightnessctl
    # XWayland 高清渲染 (Xft.dpi 加载工具)
    xrdb
  ];
}
