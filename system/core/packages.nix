{ pkgs, ... }:
{
  programs.nix-ld = {
    enable = true;
    # 与模块默认列表(取自 systemd/nix 依赖: zlib zstd stdenv.cc.cc curl openssl attr
    # libssh bzip2 libxml2 acl libsodium util-linux xz systemd)重复的项不再列出
    libraries = with pkgs; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gtk3
      icu
      libbsd
      libdrm
      libgbm
      libGL
      libICE
      libpng
      libSM
      libusb1
      libX11
      libXcomposite
      libXcursor
      libXdamage
      libXext
      libXfixes
      libXi
      libXinerama
      libxkbcommon
      libxkbfile
      libXrandr
      libXrender
      libXScrnSaver
      libXtst
      libXv
      libxcb
      mesa
      nspr
      nss
      pango
      pulseaudio
      udev
      vulkan-loader
      wayland
    ];
  };

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
