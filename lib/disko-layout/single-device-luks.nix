# 单盘 GPT + LUKS(btrfs 子卷) 布局, 挂载语义同 single-device.nix (/boot vfat, /, /home, /nix 子卷)。
# LUKS 内直接放 btrfs, 不再使用 LVM 与 tmpfs 根。swap 为随机密钥加密的 swap 分区(重启即失效, 无需口令)。
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
                "umask=0077"
              ];
            };
          };
          swap = {
            size = "16G";
            priority = 2;
            content = {
              type = "swap";
              randomEncryption = true;
            };
          };
          luks = {
            size = "100%";
            priority = 3;
            content = {
              type = "luks";
              name = "crypted";
              # lib/scripts/disko.sh 在选中 *luks* 布局时写入此文件
              passwordFile = "/tmp/secret.key";
              settings.allowDiscards = true;
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
  };
}
