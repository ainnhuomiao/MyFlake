{ inputs, ... }:
{
  imports = [ inputs.linuxqq-wayland-fix.nixosModules.default ];

  programs.linuxqq-wayland-fix = {
    enable = true;
    # QQ 本体由 home-manager 包装安装 (home/programs/im/default.nix, 强制 wayland),
    # 不重复装系统级 pkgs.qq; 启动器从 PATH 找 qq (上游已 patch 支持该命令名)
    qq = null;
  };
}
