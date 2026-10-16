{
  pkgs,
  inputs,
  ...
}:
let
  emanotePackage = inputs.emanote.packages.${pkgs.stdenv.hostPlatform.system}.emanote;
in
{
  systemd.user.tmpfiles.rules = [
    "d %h/Blog 0755 - - -"
  ];

  systemd.user.services.emanote = {
    Unit = {
      Description = "Emanote ~/Blog";
      After = [ "network.target" ];
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      Restart = "on-failure";
      RestartSec = 2;
      ExecStart = "${emanotePackage}/bin/emanote -L %h/Blog run --port=7000";
    };
  };
}
