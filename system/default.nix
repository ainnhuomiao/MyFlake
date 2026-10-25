{
  imports = [
    ./core
    # 保持代理模块原有的同级导入顺序, 避免改变 systemPackages 的合并顺序。
    ./proxy/dae.nix
    ./proxy/mihomo.nix
    ./proxy
    ./hardware
    ./nix
    ./programs
    ./virtualisation.nix
  ];
}
