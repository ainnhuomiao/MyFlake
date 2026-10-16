{
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
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
      inputs.llm-agents.packages.${system}.omp
      inputs.llm-agents.packages.${system}.pi
      inputs.llm-agents.packages.${system}.kimi-code
      inputs.llm-agents.packages.${system}.opencode2
      inputs.llm-agents.packages.${system}.opencode2-desktop
      inputs.llm-agents.packages.${system}.grok-bot
      inputs.llm-agents.packages.${system}.cursor-agent
      pkgs.omp-provider
    ]
    ++ mcps;
}
