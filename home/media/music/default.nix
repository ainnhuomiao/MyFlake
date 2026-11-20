{
  pkgs,
  appearance,
  ...
}:
let
  c = appearance.catppuccin;
  h = appearance.toHex;
in
{
  imports = [
    ./go-musicfox.nix
  ];
  home = {
    packages = with pkgs; [
      mpc
      pear-desktop
    ];
  };
  programs = {
    ncmpcpp = {
      enable = true;
      mpdMusicDir = "~/Music";
    };
    cava = {
      enable = true;
      settings = {
        color = {
          gradient = 1;
          gradient_count = 5;
          gradient_color_1 = "'${h c.blue}'";
          gradient_color_2 = "'${h c.teal}'";
          gradient_color_3 = "'${h c.mauve}'";
          gradient_color_4 = "'${h c.text}'";
          gradient_color_5 = "'${h c.yellow}'";
        };
      };
    };
  };
  services = {
    mpd = {
      enable = true;
      musicDirectory = "~/Music";
      network = {
        # 无认证, 只听回环(0.0.0.0 会把 MPD 暴露给整个 LAN)
        listenAddress = "127.0.0.1";
        port = 6600;
      };
      extraConfig = ''
        audio_output {
          type  "pipewire"
          name  "PipeWire Sound Server"
        }
      '';
    };
  };
}
