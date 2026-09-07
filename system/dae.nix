{
  me,
  lib,
  ...
}:
{
  services.dae = {
    enable = true;
    configFile = ./dae.dae;
    openFirewall.enable = false;
  };

  systemd.services.dae = {
    after = [
      "mihomo.service"
      "network-online.target"
    ];
    requires = [ "mihomo.service" ];
    wants = [ "network-online.target" ];
    restartTriggers = [ ./dae.dae ];
    # 默认不开机自启：不 want 任何 target。需启动时用 dae-toggle 手动开启。
    wantedBy = lib.mkForce [ ];
  };

  # dae 透明代理(TUN)需要放宽反向路径过滤;mihomo TUN 同理,统一在此设置
  networking.firewall.checkReversePath = "loose";

  # 与 system/mihomo.nix 的 mihomo.service 规则同款：允许用户免 sudo 启停 dae.service
  # （配合 home/programs/v2rayn 的切换脚本使用）
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        subject.user == "${me.userName}" &&
        action.id == "org.freedesktop.systemd1.manage-units" &&
        action.lookup("unit") == "dae.service"
      ) {
        return polkit.Result.YES;
      }
    });
  '';
}
