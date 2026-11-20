{
  pkgs,
  inputs,
  lib,
  ...
}:
{
  imports = [
    ./nixpkgs.nix
    ./substituters.nix
  ];

  nix = {
    channel.enable = false;
    settings = {
      nix-path = lib.mkForce [ "nixpkgs=flake:nixpkgs" ];
      experimental-features = [
        "nix-command"
        "flakes"
        "auto-allocate-uids"
        "cgroups"
      ];
      auto-allocate-uids = true;
      use-cgroups = true;
      # i5-13500H 是 12 核 16 线程，cores=16 吃满全部逻辑核。
      # 内存压力(Chromium 级链接尖峰等)由 zramSwap 吸收，见下方 zramSwap 与 OOMScoreAdjust。
      max-jobs = 2;
      cores = 16;
      auto-optimise-store = true;
      accept-flake-config = true;
      flake-registry = "${inputs.flake-registry}/flake-registry.json";
      builders-use-substitutes = true;
      keep-derivations = true;
      keep-outputs = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 2d";
    };
    package = pkgs.nixVersions.latest;
    registry.nixpkgs.flake = inputs.nixpkgs;
  };

  # zram 内存压缩 swap：优先级高于磁盘 swap(它当二线)，
  # 吸收编译期内存尖峰(clang 多 worker / electron 链接 8~12G)，
  # 换页在内存里压缩完成，避免 NVMe 换页卡顿与 OOM。
  zramSwap = {
    enable = true;
    memoryPercent = 50; # 15G 内存 → 约 7.5G zram
    priority = 100; # 高于磁盘 swap 分区(-1)，先用 zram
    algorithm = "zstd";
  };

  # 内存真到极限时，内核优先牺牲构建进程(可重跑)，而不是桌面会话。
  # use-cgroups 下构建进程都在 nix-daemon 的 cgroup 树里，继承该打分。
  systemd.services.nix-daemon.serviceConfig.OOMScoreAdjust = 500;

}
