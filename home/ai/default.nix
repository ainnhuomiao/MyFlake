{
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  omp-provider = pkgs.writeShellApplication {
    name = "omp-provider";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      findutils
      gawk
      gnused
      gnutar
      gum
      jq
      yq-go
    ];
    text = builtins.readFile ./omp-provider.sh;
  };
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
      github-copilot-cli
      claude-code
      codex
      gemini-cli
      opencode
      cc-switch
      inputs.herdr.packages.${system}.default
      inputs.llm-agents.packages.${system}.reasonix
      inputs.llm-agents.packages.${system}.antigravity-cli
      inputs.llm-agents.packages.${system}.omp
      inputs.llm-agents.packages.${system}.pi
      omp-provider
    ]
    ++ mcps;
}
