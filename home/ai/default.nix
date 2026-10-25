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
    ./mcp.nix
  ];

  home.packages =
    with pkgs;
    [
      cc-switch
      herdr
      llmAgents.omp
      llmAgents.pi
      llmAgents.kimi-code
      llmAgents.opencode2
      llmAgents.opencode2-desktop
      llmAgents.grok-bot
      llmAgents.cursor-agent
      llmAgents.chatgpt
      pkgs.omp-provider
    ]
    ++ mcps;
}
