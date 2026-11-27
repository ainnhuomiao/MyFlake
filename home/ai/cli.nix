# 物理机与 WSL 共用的命令行 AI 工具与 MCP 总线
{
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  llmAgents = inputs.llm-agents.packages.${system};
  mcps = with pkgs; [
    flake-stats-mcp
    mcp-nixos
  ];
in
{
  imports = [
    ./agy-hud.nix
    ./agy-plugins
    ./dsh
    ./mcp.nix
  ];

  home.packages =
    with pkgs;
    [
      inputs.oh-my-pi-cn.packages.${system}.omp
      llmAgents.dsh
      llmAgents.kimi-code
      llmAgents.opencode2
      llmAgents.grok-bot
      llmAgents.chatgpt
      pkgs.omp-provider
    ]
    ++ mcps;
}
