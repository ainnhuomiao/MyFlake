{
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
  };

  # dae 透明代理(TUN)需要放宽反向路径过滤;mihomo TUN 同理,统一在此设置
  networking.firewall.checkReversePath = "loose";
}
