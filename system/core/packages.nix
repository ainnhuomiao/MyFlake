{ pkgs, ... }:
{
  environment = {
    binsh = "${pkgs.dash}/bin/dash";
    shells = [ pkgs.fish ];
    systemPackages = with pkgs; [
      android-tools
      atool
      clang
      eza
      ffmpeg
      gcc
      gh
      glow
      gptfdisk
      htop
      jq
      just
      killall
      lsof
      neovim
      nix-output-monitor
      nix-tree
      nixd
      nixfmt
      onefetch
      p7zip
      pciutils
      python3
      rar
      rustscan
      socat
      sops
      tldr
      unzip
      uv
      wget
      xdg-utils
      zip
    ];
  };
}
