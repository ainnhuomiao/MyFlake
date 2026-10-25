{ lib, me, ... }:
{
  # Both transparent-proxy services are started manually through dae-toggle.
  systemd.services = lib.genAttrs [ "dae" "mihomo" ] (_: {
    wantedBy = lib.mkForce [ ];
  });

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        subject.user == "${me.userName}" &&
        action.id == "org.freedesktop.systemd1.manage-units" &&
        ["dae.service", "mihomo.service"].indexOf(action.lookup("unit")) !== -1
      ) {
        return polkit.Result.YES;
      }
    });
  '';
}
