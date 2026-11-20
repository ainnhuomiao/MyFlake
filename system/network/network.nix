{
  networking = {
    networkmanager = {
      enable = true;
    };
    # 22 由 services.openssh 模块自动放行；mpd 仅监听 127.0.0.1，无需额外放行端口
    # sing-box 手动关闭期间防 DNS 污染: 静态绑定 raw.githubusercontent.com
    hosts = {
      "185.199.108.133" = [ "raw.githubusercontent.com" ];
      "185.199.109.133" = [ "raw.githubusercontent.com" ];
      "185.199.110.133" = [ "raw.githubusercontent.com" ];
      "185.199.111.133" = [ "raw.githubusercontent.com" ];
    };
  };
}
