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
    # mihomo 停止时 dae 跟随停止, 流量退回直连而非打进死 socks 黑洞
    bindsTo = [ "mihomo.service" ];
    wants = [ "network-online.target" ];
    restartTriggers = [ ./dae.dae ];
  };

  # dae 透明代理(TUN)需要放宽反向路径过滤;mihomo TUN 同理,统一在此设置
  networking.firewall.checkReversePath = "loose";
}
