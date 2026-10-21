{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      layouts = import ../../lib/disko_layout;
      # 用 disko 上游 NixOS 模块真实求值每个布局(非手写 schema): 上游会拒绝非法的
      # 设备/分区/子卷/加密声明; 这里再断言挂载结果与现机 hardware-configuration 语义一致。
      # 纯求值, 不触碰任何磁盘。
      evalLayout =
        name: path:
        let
          cfg =
            (inputs.nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                inputs.disko.nixosModules.disko
                path
                { system.stateVersion = "26.05"; }
              ];
            }).config;
          fs = cfg.fileSystems;
          btrfsSubvol =
            mountpoint: subvol:
            let
              f = fs.${mountpoint} or null;
            in
            f != null
            && f.fsType == "btrfs"
            && lib.elem "subvol=${subvol}" f.options
            && lib.elem "compress=zstd" f.options
            && lib.elem "noatime" f.options;
          esp = fs."/boot" or null;
          valid =
            btrfsSubvol "/" "root"
            && btrfsSubvol "/home" "home"
            && btrfsSubvol "/nix" "nix"
            && esp != null
            && esp.fsType == "vfat"
            && cfg.swapDevices != [ ];
        in
        if valid then
          {
            fileSystems = lib.mapAttrs (_: f: f.fsType) fs;
            swapDevices = map (s: s.device) cfg.swapDevices;
          }
        else
          throw "disko 布局 ${name} 的挂载与现机 hardware-configuration 不一致(需 btrfs 子卷 root/home/nix + vfat /boot + swap)";
    in
    {
      # 用实际安装版本验证 KDL，避免配置语法错误导致登录后黑屏。
      checks.niri-config =
        let
          configFile = pkgs.writeText "niri-config.kdl" (
            import ../../home/wm/niri/config.nix {
              inherit lib pkgs;
              appearance = import ../../lib/appearance.nix;
            }
          );
        in
        pkgs.runCommand "niri-config" { nativeBuildInputs = [ pkgs.niri ]; } ''
          niri validate --config ${configFile}
          touch "$out"
        '';

      checks.disko-layouts =
        pkgs.runCommand "disko-layouts"
          {
            layoutManifest = builtins.toJSON (lib.mapAttrs evalLayout layouts);
            passAsFile = [ "layoutManifest" ];
          }
          ''
            cp "$layoutManifestPath" "$out"
          '';
    };
}
