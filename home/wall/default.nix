{
  pkgs,
  lib,
  config,
  appearance,
  ...
}:
let
  # 静态壁纸 = Noctalia 自带壁纸管理器;视频壁纸 = 官方 noctalia/mpvpaper 插件
  # (插件按 output 托管 mpvpaper 进程,配置见 home/programs/noctalia)。
  # 本模块提供: 稳定的壁纸/视频访问路径、切换脚本、休眠冻结视频的 unit。
  wallpaperDir = "${config.home.homeDirectory}/${appearance.wallpapersDir}";
  noctalia = lib.getExe config.programs.noctalia.package;
  pluginService = "noctalia/mpvpaper:service";
  sharedScripts = import ./share_scripts.nix {
    inherit pkgs noctalia wallpaperDir;
  };
in
{
  home.packages = [
    # mpvpaper 由插件在 PATH 中查找并拉起; socat 用于插件的 slideshow 静态帧同步
    pkgs.mpvpaper
    pkgs.socat
  ]
  ++ (with sharedScripts; [
    wallpaper_random
    dynamic_wallpaper
    default_wall
    video_wallpaper
    video_wallpaper_clear
  ]);

  # 稳定访问路径: ~/Pictures/wallpapers -> assets/wallpapers、~/Videos/wallpapers -> assets/videos
  # (两个 nix store 路径每次重建都会变,而 Noctalia/插件会持久化选中项的绝对路径)
  home.file."${appearance.wallpapersDir}".source = ../../assets/wallpapers;
  home.file."${appearance.videosDir}".source = ../../assets/videos;

  systemd.user.services = {
    # 休眠时冻结 mpvpaper,唤醒解冻(经插件 service 的 IPC;无视频分配时为空操作)
    video-wall-resume = {
      Unit = {
        Description = "Freeze/resume mpvpaper video wallpaper around suspend";
        PartOf = lib.mkForce [ "sway-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Install.WantedBy = lib.mkForce [ "sway-session.target" ];
      Service = {
        Type = "simple";
        ExecStart = pkgs.writeShellScript "video-wall-resume" ''
          ${pkgs.dbus}/bin/dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'" | \
          while read -r line; do
              if [[ "$line" == *"boolean true"* ]]; then
                  ${noctalia} msg plugin ${pluginService} all freeze || true
              elif [[ "$line" == *"boolean false"* ]]; then
                  ${noctalia} msg plugin ${pluginService} all thaw || true
              fi
          done
        '';
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
