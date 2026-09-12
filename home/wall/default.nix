{
  pkgs,
  lib,
  config,
  appearance,
  ...
}:
let
  # 静态壁纸 = Noctalia 自带壁纸管理器(background layer,配置见 home/programs/noctalia);
  # 视频壁纸 = mpvpaper,独立 unit 跑在 bottom layer 盖住静态层。
  # 壁纸资源在 assets/ 下,经 nix store 分发;Noctalia 会把选中的壁纸绝对路径
  # 持久化到 settings.toml,所以额外给一份稳定的 home symlink 访问路径。
  wallpaperDir = "${config.home.homeDirectory}/${appearance.wallpapersDir}";
  noctalia = lib.getExe config.programs.noctalia.package;
  sharedScripts = import ./share_scripts.nix {
    inherit pkgs noctalia wallpaperDir;
  };
in
{
  home.packages = [
    pkgs.mpvpaper
    pkgs.socat
  ]
  ++ (with sharedScripts; [
    wallpaper_random
    dynamic_wallpaper
    default_wall
    video_wallpaper
    video_wallpaper_next
  ]);

  # 稳定访问路径: ~/Pictures/wallpapers -> assets/wallpapers (nix store)
  home.file."${appearance.wallpapersDir}".source = ../../assets/wallpapers;

  systemd.user.services = {
    # mpvpaper 视频壁纸:默认壁纸,随 sway 会话自动启动;
    # 切静态由 video_wallpaper 脚本 stop,切回视频再 start。
    video-wall = {
      Unit = {
        Description = "mpvpaper video wallpaper";
        PartOf = lib.mkForce [ "sway-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Install.WantedBy = lib.mkForce [ "sway-session.target" ];
      Service = {
        Type = "simple";
        ExecStart = "${sharedScripts.video_wallpaper_play}/bin/video_wallpaper_play";
        Restart = "no";
      };
    };

    # 休眠时暂停视频壁纸,唤醒后恢复(通过 mpvpaper 的 IPC socket)
    video-wall-resume = {
      Unit = {
        Description = "Pause/resume mpvpaper around suspend";
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
                  echo 'set pause yes' | ${pkgs.socat}/bin/socat - /tmp/mpvpaper.sock || true
              elif [[ "$line" == *"boolean false"* ]]; then
                  echo 'set pause no' | ${pkgs.socat}/bin/socat - /tmp/mpvpaper.sock || true
              fi
          done
        '';
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
