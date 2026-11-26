# WSL2 专用 Home Manager 入口: 完整 CLI + 开发工具链 + AI CLI/MCP, 不含桌面与仅 Linux 桌面 GUI 应用
{ lib, ... }:
{
  imports = [
    ./base.nix
    ./ai/cli.nix
    ./cli/common.nix
    ./dev
    ./editors/helix.nix
    ./editors/neovim.nix
    ./shell/common.nix
  ];

  # Windows Terminal 等宿主机终端不支持 kitty-direct 图像协议, 回退为内置 NixOS 字符图标
  programs.fastfetch.settings.logo = lib.mkForce {
    type = "builtin";
    source = "nixos";
  };

  # 让 gh / s-search / xdg-open 等 CLI 工具通过 wsl-open 调用 Windows 默认浏览器打开链接
  home.sessionVariables.BROWSER = "wsl-open";
}
