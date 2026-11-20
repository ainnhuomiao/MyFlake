{
  boot.loader.grub = {
    # GRUB 界面放大 ≈1.5 倍: 内屏原生 2560x1600, 1/1.5 = 1706x1067 非标准模式
    # GRUB 会 fallback, 取 EDID 中最接近的 16:10 标准模式 1680x1050 (≈1.52x)
    gfxmodeEfi = "1680x1050,auto";
  };

  nix.settings = {
    # i5-13500H 是 12 核 16 线程，cores=16 吃满全部逻辑核。
    # 内存压力(Chromium 级链接尖峰等)由 zramSwap 吸收，见下方 zramSwap 与 OOMScoreAdjust。
    max-jobs = 2;
    cores = 16;
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
