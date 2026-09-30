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
      mpdMusicDir = null;
      settings = {
        mpd_music_dir = "~/Music";
      };
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
  home.file.".config/cava/config_internal".text = ''
    [general]
    bars = 12
    sleep_timer = 10
    [output]
    method = raw
    data_format = ascii
    ascii_max_range = 7
  ''; # cava 的 raw ascii 输出配置 (Noctalia bar 无 cava 可视化,保留供终端手动 cava 使用)
  services = {
    mpd = {
      enable = true;
      musicDirectory = "~/Music";
      network = {
        listenAddress = "0.0.0.0";
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
