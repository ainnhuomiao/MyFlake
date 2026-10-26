{
  pkgs,
  configDirectory ? "/var/lib/sing-box-config",
  directRules ? {
    domains = [ ];
    ipCidrs = [ ];
  },
}:
let
  python = pkgs.python3.withPackages (packages: [ packages.pyyaml ]);
  environment = ''
    export SINGBOX_CONFIG_DIR=${pkgs.lib.escapeShellArg configDirectory}
    export SINGBOX_SUBSCRIPTIONS_FILE="$SINGBOX_CONFIG_DIR/subscriptions.yaml"
    export SINGBOX_CONFIG_FILE="$SINGBOX_CONFIG_DIR/config.json"
    export SINGBOX_PROVIDER_DIR="$SINGBOX_CONFIG_DIR/providers"
    export SINGBOX_CLASH_API_SECRET_FILE="$SINGBOX_CONFIG_DIR/clash-api-secret"
    export SINGBOX_CHANGED_FILE="$SINGBOX_CONFIG_DIR/.config-changed"
    export SINGBOX_DIRECT_RULES=${pkgs.lib.escapeShellArg (builtins.toJSON directRules)}
    export SINGBOX_STATE_DIR=/var/lib/sing-box
    export SINGBOX_BIN=${pkgs.lib.getExe pkgs.sing-box}
    export SINGBOX_DASHBOARD_DIR=${pkgs.metacubexd}
    export SINGBOX_GEOSITE_DIR=${pkgs.sing-geosite}/share/sing-box/rule-set
    export SINGBOX_GEOIP_DIR=${pkgs.sing-geoip}/share/sing-box/rule-set
  '';
in
{
  generateConfig = pkgs.writeShellApplication {
    name = "sing-box-generate-config";
    runtimeInputs = with pkgs; [
      coreutils
      curl
    ];
    text = environment + ''
      exec ${python}/bin/python3 ${./generate-config.py}
    '';
  };

  subscriptionManager = pkgs.writeShellApplication {
    name = "sing-box-sub";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
      systemd
      yq-go
    ];
    text = environment + builtins.readFile ./sing-box-sub.sh;
  };
}
