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
    ./agy-permissions.nix
    ./mcp.nix
  ];

  home.packages =
    with pkgs;
    [
      codex
      opencode
      cc-switch
      inputs.herdr.packages.${system}.default
      inputs.llm-agents.packages.${system}.antigravity-cli
      inputs.llm-agents.packages.${system}.omp
      inputs.llm-agents.packages.${system}.pi
      inputs.llm-agents.packages.${system}.kimi-code
      pkgs.omp-provider
    ]
    ++ mcps;
}
