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

  # 歌词插件独立钉版(path source)；plugin_api = 3 与 v5.2.1 兼容。
  lyricsPlugins = pkgs.fetchFromGitHub {
    owner = "OHMCFXG";
    repo = "noctalia-plugins";
    rev = "83588236d5f7f0b4212249fa1d08bd4e44177a8c";
    hash = "sha256-din8sm4TQCRQqdGg80O0pxsqc5gKK2GXmUndAzWW2KQ=";
  };
in
{
  programs.noctalia = {
    enable = true;
    package = noctaliaPackage;
    settings = {
      # 深色 Shell 使用高饱和壁纸取色，鲜艳颜色只作为强调，不把栏体洗白。
      theme = {
        mode = "dark";
        shell_mode = "dark";
        source = "wallpaper";
        wallpaper_scheme = "vibrant";
      };
      # 连续高对比浮岛栏：普通模块融入栏体，只有中央时钟保留强调色胶囊。
      bar.order = [
        "default"
        "bottom"
      ];
      bar.default = {
        position = "top";
        thickness = 38;
        margin_ends = 160;
        margin_edge = 6;
        padding = 12;
        widget_spacing = 10;
        radius = 10;
        background_opacity = 0.84;
        compositor_blur = true;
        concave_edge_corners = false;
        contact_shadow = true;
        shadow = true;
        font_family = "Noto Sans CJK SC";
        font_weight = 500;
        color = "on_surface";
        capsule = false;
        start = [
          "launcher"
          "workspaces"
          "active_window"
          "group:wallpaper"
        ];
        center = [ "clock" ];
        end = [
          "tray"
          "group:status"
          "group:actions"
        ];
        capsule_group = [
          {
            id = "wallpaper";
            members = [
              "wallpaper"
              "mpvpaper"
            ];
            accordion = true;
            accordion_direction = "end";
            fill = "surface";
            foreground = "on_surface";
            opacity = 0.0;
            padding = 0.0;
            border = "";
          }
          {
            id = "status";
            members = [
              "network"
              "bluetooth"
              "volume"
              "battery"
            ];
            fill = "surface";
            foreground = "on_surface";
            opacity = 0.0;
            padding = 0.0;
            border = "";
          }
          {
            id = "actions";
            members = [
              "notifications"
              "control-center"
              "session"
            ];
            fill = "surface";
            foreground = "on_surface";
            opacity = 0.0;
            padding = 0.0;
            border = "";
          }
        ];
      };
      # 底栏补充媒体、系统状态和少量工具，不重复顶栏信息。
      bar.bottom = {
        position = "bottom";
        thickness = 28;
        margin_ends = 320;
        margin_edge = 6;
        padding = 12;
        widget_spacing = 10;
        radius = 10;
        background_opacity = 0.76;
        compositor_blur = true;
        concave_edge_corners = false;
        contact_shadow = true;
        shadow = true;
        reserve_space = true;
        font_family = "Noto Sans CJK SC";
        font_weight = 500;
        color = "on_surface";
        capsule = false;
        start = [
          "audio_visualizer"
          "media"
        ];
        center = [
          "bottom_cpu"
          "bottom_ram"
          "bottom_net_rx"
          "bottom_net_tx"
        ];
        end = [
          "bottom_lyrics"
          "caffeine"
          "clipboard"
          "settings"
        ];
      };
      widget = {
        clock = {
          font_weight = 600;
          capsule = true;
          capsule_fill = "primary";
          capsule_foreground = "on_primary";
          capsule_opacity = 0.92;
          capsule_padding = 8.0;
          capsule_radius = 10.0;
        };
        audio_visualizer = {
          width = 96;
          bands = 24;
          show_when_idle = false;
          color_1 = "primary";
          color_2 = "secondary";
        };
        media = {
          artist_first = true;
          max_length = 240;
          title_scroll = "on_hover";
          hide_when_no_media = true;
        };
        bottom_lyrics = {
          type = "0x1ce/mpris-lyrics:bar";
          barMaxWidth = 280;
          barWidthMode = "fixed";
          textAlign = "right";
          barHideWhenIdle = true;
          showBarStatusDot = false;
          showSecondaryLine = false;
        };
        bottom_cpu = {
          type = "sysmon";
          stat = "cpu_usage";
          visualization = "none";
          label_min_width = 48.0;
        };
        bottom_ram = {
          type = "sysmon";
          stat = "ram_used";
          visualization = "none";
          label_min_width = 56.0;
        };
        bottom_net_rx = {
          type = "sysmon";
          stat = "net_rx";
          visualization = "none";
          network_speed_compact = true;
          label_min_width = 72.0;
        };
        bottom_net_tx = {
          type = "sysmon";
          stat = "net_tx";
          visualization = "none";
          network_speed_compact = true;
          label_min_width = 72.0;
        };
      };
      # 桌面保持留白，信息由上下栏与按需打开的面板承担。
      desktop_widgets.enabled = false;
      notification = {
        background_opacity = 0.94;
        border = true;
        offset_y = 16;
      };
      osd = {
        position = "bottom_center";
        background_opacity = 0.9;
        border = false;
        offset_y = 24;
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
        enabled = [
          "noctalia/mpvpaper"
          "0x1ce/mpris-lyrics"
        ];
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
            name = "personal";
            kind = "path";
            location = "${lyricsPlugins}";
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
      plugin_settings."0x1ce/mpris-lyrics" = {
        primaryLyricsSource = "netease";
        playerFilterMode = "blacklist";
        playerFilterList = [
          "firefox"
          "chrome"
          "zen"
        ];
        preferPlayerLyrics = false;
        lyricAdvanceMs = 0;
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
      # 无衬线字体、附着的仪表盘与浮动工具面板形成统一、克制的层级。
      shell = {
        lang = "zh-Hans";
        font_family = "Noto Sans CJK SC";
        corner_radius_scale = 1.0;
        animation = {
          enabled = true;
          speed = 1.0;
        };
        shadow = {
          direction = "down";
          alpha = 0.32;
        };
        panel = {
          transparency_mode = "soft";
          borders = true;
          shadow = true;
          launcher_placement = "floating";
          clipboard_placement = "floating";
          control_center_placement = "attached";
          wallpaper_placement = "attached";
          session_placement = "floating";
          launcher_position = "center";
          clipboard_position = "center";
        };
      };
    };
    # 不启用 systemd service: 用合成器 autostart 自启, 避免在 wayland socket 就绪前启动
  };
}
