{
  pkgs,
  lib,
  me,
  ...
}:
let
  userName = me.userName;
  configGroup = "sing-box-config";
  configDirectory = "/var/lib/sing-box-config";
  configFile = "${configDirectory}/config.json";
  subscriptionsFile = "${configDirectory}/subscriptions.yaml";
  providerDirectory = "${configDirectory}/providers";
  changedFile = "${configDirectory}/.config-changed";

  rules = import ../../lib/proxy/rules.nix;
  tools = import ../../lib/proxy {
    inherit pkgs configDirectory;
    directRules = rules.direct;
  };
  inherit (tools) generateConfig subscriptionManager;

  restartIfChanged = pkgs.writeShellScript "sing-box-restart-if-changed" ''
    set -e
    if [ -e "${changedFile}" ]; then
      ${pkgs.systemd}/bin/systemctl try-restart sing-box.service
      ${pkgs.coreutils}/bin/rm -f "${changedFile}"
    fi
  '';
in
{
  services.sing-box.enable = true;

  users.groups.${configGroup} = { };
  users.users.${userName}.extraGroups = [ configGroup ];

  environment.systemPackages = [ subscriptionManager ];

  networking.firewall.checkReversePath = "loose";

  systemd.services.sing-box = {
    wantedBy = lib.mkForce [ ];
    serviceConfig = {
      SupplementaryGroups = [ configGroup ];
      ExecStart = lib.mkForce [
        ""
        "${lib.getExe pkgs.sing-box} -D \${STATE_DIRECTORY} -c ${configFile} run"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d ${configDirectory} 2770 ${userName} ${configGroup} -"
    "d ${providerDirectory} 2770 ${userName} ${configGroup} -"
  ];

  systemd.services.sing-box-config-regenerate = {
    description = "Regenerate sing-box config after subscription changes";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    restartTriggers = [ generateConfig ];
    serviceConfig = {
      Type = "oneshot";
      User = userName;
      Group = configGroup;
      ExecStart = "${generateConfig}/bin/sing-box-generate-config";
      ExecStartPost = "+${restartIfChanged}";
    };
  };

  systemd.paths.sing-box-config-regenerate = {
    description = "Watch sing-box subscriptions";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = subscriptionsFile;
      Unit = "sing-box-config-regenerate.service";
    };
  };

  systemd.timers.sing-box-config-regenerate = {
    description = "Refresh sing-box subscriptions daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
      Unit = "sing-box-config-regenerate.service";
    };
  };

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        subject.user == "${userName}" &&
        action.id == "org.freedesktop.systemd1.manage-units" &&
        action.lookup("unit") == "sing-box.service"
      ) {
        return polkit.Result.YES;
      }
    });
  '';

  system.activationScripts.singBoxConfig = {
    deps = [ "users" ];
    text = ''
      install -d -o ${userName} -g ${configGroup} -m 2770 \
        "${configDirectory}" \
        "${providerDirectory}"

      if [ ! -e "${subscriptionsFile}" ] && [ ! -L "${subscriptionsFile}" ]; then
        install -o ${userName} -g ${configGroup} -m 0600 /dev/null "${subscriptionsFile}"
        printf 'subscriptions: {}\n' > "${subscriptionsFile}"
      fi
    '';
  };
}
