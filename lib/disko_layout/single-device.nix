# 单盘 GPT + btrfs 子卷布局, 挂载语义与 hosts/nixos/hardware-configuration.nix 一致:
#   /boot (vfat) · / (subvol=root) · /home (subvol=home) · /nix (subvol=nix) · swap
# 子卷名与挂载选项(compress=zstd, noatime)同现机。现机 btrfs 跨 nvme0n1p8/p9 两个分区
# (多设备), disko 的 btrfs 只支持单设备, 故这里是同挂载语义的单盘等价布局。
# 普通根分区 (无 impermanence): 数据全部落盘, 不使用 tmpfs 根。
# 注意: device 为模板路径, 执行前必须用 lsblk 核对, 整盘会被清空。
# fix eval warning: https://github.com/nix-community/disko/blob/master/docs/table-to-gpt.md
let
  btrfsOptions = [
    "compress=zstd"
    "noatime"
  ];
in
{
  disko.devices = {
    disk.main = {
      device = "/dev/nvme0n1";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            priority = 1;
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "fmask=0022"
                "dmask=0022"
              ];
            };
          };
          swap = {
            size = "16G";
            priority = 2;
            content = {
              type = "swap";
            };
          };
          root = {
            size = "100%";
            priority = 3;
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                root = {
                  mountpoint = "/";
                  mountOptions = btrfsOptions;
                };
                home = {
                  mountpoint = "/home";
                  mountOptions = btrfsOptions;
                };
                nix = {
                  mountpoint = "/nix";
                  mountOptions = btrfsOptions;
                };
              };
            };
          };
        };
      };
    };
  };
}
