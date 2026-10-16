{
  pkgs,
  me,
  ...
}:

let
  userName = me.userName;
  configGroup = "mihomo-config";
  configDirectory = "/var/lib/mihomo-config";
  configFile = "${configDirectory}/config.yaml";
  subscriptionsFile = "${configDirectory}/subscriptions.yaml";
  providerDirectory = "${configDirectory}/proxy-providers";

  zashboard = pkgs.fetchzip {
    url = "https://github.com/Zephyruso/zashboard/releases/download/v3.16.0/dist.zip";
    hash = "sha256-HnbkkmDJeTE+ynvgLevWuGGRVjUlO8fIAGaPHLHxbj8=";
  };

  tools = import ../lib/proxy-tools.nix { inherit pkgs configDirectory; };
  inherit (tools) generateConfig subscriptionManager;

  # generate→chgrp→chmod 0640 供 systemd regenerate 服务与 activation script 共用;
  # set -e 与 systemd job script 语义一致: generate 失败即中止, 不碰旧配置、不触发重启
  regenerateConfig = pkgs.writeShellScript "mihomo-regenerate-config" ''
    set -e
    ${pkgs.util-linux}/bin/runuser -u ${userName} -- \
      ${generateConfig}/bin/mihomo-generate-config
    chgrp ${configGroup} "${configFile}"
    chmod 0640 "${configFile}"
  '';
in
{
  services.mihomo = {
    enable = true;
    tunMode = false;
    configFile = configFile;
    webui = zashboard;
  };

  users.groups.${configGroup} = { };
  users.users.${userName}.extraGroups = [ configGroup ];

  systemd.services.mihomo.serviceConfig = {
    SupplementaryGroups = [ configGroup ];
    ReadWritePaths = [ configDirectory ];
  };
  systemd.services.mihomo.environment.SAFE_PATHS = configDirectory;

  environment.systemPackages = [ subscriptionManager ];

  systemd.tmpfiles.rules = [
    "d ${configDirectory} 2770 ${userName} ${configGroup} -"
    "d ${providerDirectory} 2770 ${userName} ${configGroup} -"
  ];

  systemd.services.mihomo-config-regenerate = {
    description = "Regenerate Mihomo config after subscription changes";
    serviceConfig.Type = "oneshot";
    script = ''
      ${regenerateConfig}
      systemctl try-restart mihomo.service
    '';
  };

  systemd.paths.mihomo-config-regenerate = {
    description = "Watch Mihomo subscriptions";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = subscriptionsFile;
      Unit = "mihomo-config-regenerate.service";
    };
  };

  system.activationScripts.mihomoConfig = {
    deps = [ "users" ];
    text = ''
      install -d -o ${userName} -g ${configGroup} -m 2770 \
        "${configDirectory}" \
        "${providerDirectory}"

      if [ ! -e "${subscriptionsFile}" ]; then
        install -o ${userName} -g ${configGroup} -m 0600 /dev/null "${subscriptionsFile}"
        printf 'subscriptions: {}\n' > "${subscriptionsFile}"
      fi

      chown ${userName}:${configGroup} "${subscriptionsFile}"
      chmod 0600 "${subscriptionsFile}"

      ${regenerateConfig}
    '';
  };
}
