{
  config,
  lib,
  pkgs,
  me,
  appearance,
  ...
}:
{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  networking.hostName = "nixos-wsl";

  wsl = {
    enable = true;
    defaultUser = me.userName;
    # 透传 Windows 宿主机 GPU 驱动 (/usr/lib/wsl/lib -> /run/opengl-driver/lib),
    # 供 CUDA 计算与 WSLg 硬件加速使用 (NixOS-WSL 会自动开启 hardware.graphics.enable)
    useWindowsDriver = true;
    # 为 WSLg GUI 应用同步 Windows 开始菜单快捷方式
    startMenuLaunchers = true;
    interop = {
      # 保留 Windows PATH, 支持直接调用 code / explorer.exe / powershell.exe 等
      includePath = true;
    };
  };

  # NixOS-WSL 通过 populateBin 把 /bin/sh 指向带环境包装的 wsl.binShExe;
  # 让 environment.binsh 与之一致, 避免 activationScripts.binsh 与 populateBin 竞态覆盖 /bin/sh
  environment.binsh = config.wsl.binShExe;

  # 让 /usr/lib/wsl/lib 下的宿主机工具 (如 nvidia-smi) 可直接调用
  environment.variables.PATH = [ "/usr/lib/wsl/lib" ];

  # 把 Windows 宿主机 GPU 驱动库也加入 nix-ld, 让未打补丁的 Python CUDA wheel / 动态链接二进制直接找到 libcuda.so.1
  programs.nix-ld.libraries = [ config.wsl.wslLib ];

  # 允许用户访问 WSLg / /dev/dxg 图形设备
  users.users.${me.userName}.extraGroups = [ "video" ];

  # WSLg GUI 字体支持: 本地提供主字体与 CJK/Emoji, 并回退到 Windows 宿主机字体目录
  fonts = {
    packages = with pkgs; [
      maple-mono.NF-CN
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        emoji = [ "Noto Color Emoji" ];
        serif = [
          appearance.font.name
          "Noto Serif CJK SC"
          "SimSun"
        ];
        sansSerif = [
          appearance.font.name
          "Noto Sans CJK SC"
          "Microsoft YaHei"
        ];
        monospace = [
          appearance.font.name
          "Noto Sans Mono CJK SC"
        ];
      };
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <dir>/mnt/c/Windows/Fonts</dir>
        </fontconfig>
      '';
    };
  };

  # WSL 专用工具: wl-clipboard (WSLg Wayland 剪贴板, 供 Neovim unnamedplus 使用)、wsl-open (调用 Windows 宿主应用打开文件/链接)
  environment.systemPackages = with pkgs; [
    wl-clipboard
    wsl-open
  ];

  # stateVersion 记录首次安装时的 NixOS release, 升级后不要随意改动
  system.stateVersion = "26.05";
}
