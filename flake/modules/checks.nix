{
  perSystem =
    { pkgs, lib, ... }:
    let
      layouts = import ../../lib/disko_layout;
      field =
        path: value:
        if path == [ ] then
          value
        else if builtins.isAttrs value && builtins.hasAttr (builtins.head path) value then
          field (builtins.tail path) value.${builtins.head path}
        else
          null;
      values = value: if builtins.isAttrs value then builtins.attrValues value else [ ];
      nonEmptyAttrs = value: builtins.isAttrs value && value != { };
      nonEmptyString = value: builtins.isString value && value != "";
      absolutePath = value: nonEmptyString value && lib.hasPrefix "/" value;
      stringList = value: builtins.isList value && builtins.all builtins.isString value;
      validateLayout =
        name: path:
        let
          layout = import path;
          devices = field [ "disko" "devices" ] layout;
          disks = field [ "disk" ] devices;
          volumeGroups = field [ "lvm_vg" ] devices;
          validateContent =
            content:
            let
              type = field [ "type" ] content;
              mountOptions = field [ "mountOptions" ] content;
              allowDiscards = field [ "settings" "allowDiscards" ] content;
              vg = field [ "vg" ] content;
            in
            if type == "filesystem" then
              nonEmptyString (field [ "format" ] content)
              && absolutePath (field [ "mountpoint" ] content)
              && (mountOptions == null || stringList mountOptions)
            else if type == "luks" then
              nonEmptyString (field [ "name" ] content)
              && absolutePath (field [ "passwordFile" ] content)
              && (allowDiscards == null || builtins.isBool allowDiscards)
              && validateContent (field [ "content" ] content)
            else if type == "lvm_pv" then
              nonEmptyString vg && builtins.isAttrs volumeGroups && builtins.hasAttr vg volumeGroups
            else
              false;
          validatePartition =
            partition:
            nonEmptyString (field [ "size" ] partition)
            && builtins.isInt (field [ "priority" ] partition)
            && validateContent (field [ "content" ] partition);
          validateDisk =
            disk:
            let
              device = field [ "device" ] disk;
              partitions = field [ "content" "partitions" ] disk;
              esp = field [ "ESP" ] partitions;
            in
            field [ "type" ] disk == "disk"
            && nonEmptyString device
            && lib.hasPrefix "/dev/" device
            && field [ "content" "type" ] disk == "gpt"
            && nonEmptyAttrs partitions
            && builtins.all validatePartition (values partitions)
            && field [ "type" ] esp == "EF00"
            && field [ "content" "type" ] esp == "filesystem"
            && field [ "content" "format" ] esp == "vfat"
            && field [ "content" "mountpoint" ] esp == "/boot";
          validateVolumeGroup =
            group:
            let
              volumes = field [ "lvs" ] group;
            in
            field [ "type" ] group == "lvm_vg"
            && nonEmptyAttrs volumes
            && builtins.all (
              volume: nonEmptyString (field [ "size" ] volume) && validateContent (field [ "content" ] volume)
            ) (values volumes);
          filesystems =
            lib.concatMap (
              disk:
              map (partition: field [ "content" ] partition) (values (field [ "content" "partitions" ] disk))
            ) (values disks)
            ++ lib.concatMap (
              group: map (volume: field [ "content" ] volume) (values (field [ "lvs" ] group))
            ) (values volumeGroups);
          valid =
            nonEmptyAttrs disks
            && builtins.all validateDisk (values disks)
            && (volumeGroups == null || builtins.isAttrs volumeGroups)
            && builtins.all validateVolumeGroup (values volumeGroups)
            && field [ "nodev" "/" "fsType" ] devices == "tmpfs"
            && stringList (field [ "nodev" "/" "mountOptions" ] devices)
            && builtins.any (
              filesystem:
              field [ "type" ] filesystem == "filesystem"
              && field [ "format" ] filesystem == "ext4"
              && field [ "mountpoint" ] filesystem == "/nix"
            ) filesystems;
        in
        if valid then builtins.deepSeq layout layout else throw "Invalid disk layout: ${name}";
      validatedLayouts = lib.mapAttrs validateLayout layouts;
    in
    {
      checks.disko-layouts =
        pkgs.runCommand "disko-layouts"
          {
            layoutManifest = builtins.toJSON validatedLayouts;
            passAsFile = [ "layoutManifest" ];
          }
          ''
            cp "$layoutManifestPath" "$out"
          '';
    };
}
