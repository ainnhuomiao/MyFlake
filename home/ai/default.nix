{
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  llmAgents = inputs.llm-agents.packages.${system};
in
{
  imports = [
    ./cli.nix
  ];

  # 仅桌面环境安装的 AI GUI 应用
  home.packages = with pkgs; [
    herdr
    inputs.magpie.packages.${system}.default
    pkgs.workbuddy
    llmAgents.opencode2-desktop
  ];
}
