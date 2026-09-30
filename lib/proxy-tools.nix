{
  pkgs,
  configDirectory ? "/var/lib/mihomo-config",
}:
let
  paths = ''
    configDirectory=${pkgs.lib.escapeShellArg configDirectory}
    subscriptionsFile="$configDirectory/subscriptions.yaml"
  '';
  shared = builtins.readFile ./scripts/proxy-stack.sh;
in
{
  inherit shared;
  generateConfig = pkgs.writeShellApplication {
    name = "mihomo-generate-config";
    runtimeInputs = with pkgs; [
      coreutils
      mihomo
      yq-go
    ];
    text =
      paths
      + ''
        configFile="$configDirectory/config.yaml"
        providerDirectory="$configDirectory/proxy-providers"
      ''
      + builtins.readFile ./scripts/mihomo-generate-config.sh;
  };
  subscriptionManager = pkgs.writeShellApplication {
    name = "mihomo-sub";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
      systemd
      yq-go
    ];
    text = paths + builtins.readFile ./scripts/mihomo-sub.sh;
  };
}
