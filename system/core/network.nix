{
  networking = {
    networkmanager = {
      enable = true;
    };
    firewall.allowedTCPPorts = [
      # 22 由 services.openssh 模块自动放行, 不再重复列出
      6600 # mpd
    ];
    # dae 手动关闭期间防 DNS 污染: 静态绑定 raw.githubusercontent.com
    hosts = {
      "185.199.109.133" = [ "raw.githubusercontent.com" ];
    };
  };
}
