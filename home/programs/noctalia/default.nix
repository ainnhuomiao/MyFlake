{
  config,
  inputs,
  pkgs,
  appearance,
  ...
}:
let
  # 稳定路径: Noctalia(壁纸管理器)与 mpvpaper 插件都会把选中的壁纸/视频绝对路径
  # 持久化进自己的 state,用 home symlink(见 home/wall)而非 store 路径,重建后才不失效
  wallpaperDir = "${config.home.homeDirectory}/${appearance.wallpapersDir}";
  videoDir = "${config.home.homeDirectory}/${appearance.videosDir}";

  # 透明浮岛栏只模糊胶囊，不模糊胶囊之间的空白；升级 Noctalia 时需复核补丁。
  noctaliaPackage =
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
      (old: {
        patches = (old.patches or [ ]) ++ [ ../../../patches/noctalia-transparent-bar-capsule-blur.patch ];
      });

  # 官方插件源钉版(path source,不联网;升级 noctalia 时同步 bump)。
  # 依赖关系:插件的 plugin_api 必须落在 shell 支持区间内 —— v5.2.1 为 3..32,
  # noctalia/mpvpaper 声明 plugin_api = 9。
  officialPlugins = pkgs.fetchFromGitHub {
    owner = "noctalia-dev";
    repo = "official-plugins";
    rev = "233782933e999bc69aca1ac6bc1bb285b6b26a3e";
    hash = "sha256-d/eZuJ2MJ8Ugqzf4QAmIx19Sy/6101BdfI5F5FBp5+I=";
  };
in
{
  programs.noctalia = {
    enable = true;
    package = noctaliaPackage;
    settings = {
      theme = {
        mode = "dark";
        source = "wallpaper";
        wallpaper_scheme = "soft";
        builtin = "Catppuccin";
      };
      # 三段式浮岛栏：栏间保持透明，仅胶囊请求背景模糊；胶囊与前景色跟随壁纸配对。
      bar.default = {
        thickness = 40;
        margin_ends = 12;
        margin_edge = 6;
        padding = 8;
        widget_spacing = 6;
        radius = 12;
        background_opacity = 0.0;
        compositor_blur = true;
        concave_edge_corners = false;
        contact_shadow = true;
        font_family = appearance.font.name;
        capsule = true;
        capsule_fill = "primary";
        capsule_foreground = "on_primary";
        capsule_opacity = 0.65;
        capsule_padding = 8.0;
        capsule_radius = 10.0;
        capsule_border = "outline";
        capsule_border_width = 0.6;
        start = [
          "launcher"
          "group:g4"
          "workspaces"
          "group:g2"
        ];
        center = [ "clock" ];
        end = [
          "group:g1"
          "group:g3"
          "group:g5"
          "tray"
          "notifications"
          "session"
          "control-center"
        ];
        capsule_group = [
          {
            id = "g1";
            members = [
              "network_tx"
              "network_rx"
              "network"
              "bluetooth"
            ];
            accordion = true;
            accordion_direction = "start";
            fill = "primary";
            foreground = "on_primary";
            opacity = 0.65;
            padding = 6.0;
            border = "outline";
            border_width = 0.6;
          }
          {
            id = "g2";
            members = [
              "audio_visualizer"
              "media"
            ];
            fill = "primary";
            foreground = "on_primary";
            opacity = 0.65;
            padding = 6.0;
            border = "outline";
            border_width = 0.6;
          }
          {
            id = "g3";
            members = [
              "battery"
              "volume"
            ];
            fill = "primary";
            foreground = "on_primary";
            opacity = 0.65;
            padding = 6.0;
            border = "outline";
            border_width = 0.6;
          }
          {
            id = "g4";
            members = [
              "wallpaper"
              "mpvpaper"
            ];
            accordion = true;
            accordion_direction = "end";
            fill = "primary";
            foreground = "on_primary";
            opacity = 0.65;
            padding = 6.0;
            border = "outline";
            border_width = 0.6;
          }
          {
            id = "g5";
            members = [
              "cpu"
              "ram"
              "brightness"
            ];
            accordion = true;
            accordion_direction = "start";
            fill = "primary";
            foreground = "on_primary";
            opacity = 0.65;
            padding = 6.0;
            border = "outline";
            border_width = 0.6;
          }
        ];
      };
      widget = {
        clock.font_weight = 700;
        audio_visualizer = {
          color_1 = "on_primary";
          color_2 = "on_primary";
        };
        media = {
          hide_artist = true;
          hide_when_no_media = true;
          max_length = 40;
        };
      };
      # 静态壁纸由 Noctalia 自带壁纸管理器渲染(background layer、
      # 选择器面板 panel-toggle wallpaper、IPC wallpaper-random/set)
      wallpaper = {
        enabled = true;
        directory = wallpaperDir;
        default = {
          path = "${wallpaperDir}/default.png";
        };
      };
      # 视频壁纸交给官方 mpvpaper 插件:插件按 output 托管 mpvpaper 进程,
      # 并在有视频的 output 上让 Noctalia 收起自己的壁纸层(setWallpaperEnabled)
      plugins = {
        enabled = [ "noctalia/mpvpaper" ];
        # 插件来自钉版 path source(见下),不需要联网更新
        auto_update = "none";
        source = [
          {
            name = "official";
            kind = "path";
            location = "${officialPlugins}";
            enabled = true;
          }
          {
            # 不用社区插件;显式关掉,避免后台/设置页触发 git clone
            name = "community";
            kind = "git";
            location = "https://github.com/noctalia-dev/community-plugins";
            enabled = false;
          }
        ];
      };
      # 插件级设置(键必须是插件 manifest 里声明过的)
      plugin_settings."noctalia/mpvpaper" = {
        video_directory = videoDir;
        # 默认 full:有最大化/全屏窗口时暂停 mpv。终端是半透明的,视频仍可见,
        # 暂停会看到定格画面,故保持始终播放(与原 video-wall service 行为一致)
        auto_pause = "off";
        # 用户 mpv 配置(vo=gpu + profile=gpu-hq)与 mpvpaper 的 libmpv 渲染冲突,
        # 实测丢帧 400+/播放 0.1x;no-config 后接近实时
        mpv_options = "no-config";
        # 关掉"清除视频时用 ffmpeg 抽最后一帧当壁纸":抽帧是异步的,
        # 会与 wallpaper_random/default_wall 紧接着设置的壁纸竞争
        extract_last_frame = false;
      };
      # 锁屏背景: 捕捉当前桌面(含 mpvpaper 视频壁纸那一帧)做模糊+着色,
      # 复刻旧 swaylock-blur 的模糊壁纸效果
      lockscreen = {
        blurred_desktop = true;
      };
      # getty 自动登录无法解锁密钥环;主密钥使用用户私有文件,避免启动时弹窗。
      storage = {
        key_source = "file";
        key_file = "${config.home.homeDirectory}/.config/noctalia/storage-key";
      };
      # 中文界面 (系统 locale 是 en_US, 默认会是英文)
      shell = {
        lang = "zh-Hans";
      };
    };
    # 不启用 systemd service: 用合成器 autostart 自启, 避免在 wayland socket 就绪前启动
  };
}
