{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations =
    let
      me = import ../me.nix;
      inherit (inputs.nixpkgs.lib) nixosSystem;
      specialArgs = {
        inherit inputs self me;
        appearance = import ../lib/appearance.nix;
      };
      mkHomeManager = homeModule: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          extraSpecialArgs = specialArgs;
          users.${me.userName}.imports = [ homeModule ];
        };
      };
    in
    {
      nixos = nixosSystem {
        specialArgs = specialArgs;
        modules = [
          ./nixos
          ../system
          inputs.disko.nixosModules.disko
          inputs.ncro.nixosModules.ncro
          # fork 的 NixOS 模块: 覆盖 programs.niri.package 为用宿主 pkgs 构建的 fork,
          # 并把 niri 自带的 portal 加入 extraPortals。
          inputs.niri.nixosModules.niri
          inputs.home-manager.nixosModules.home-manager
          (mkHomeManager ../home)
        ];
      };

      nixos-wsl = nixosSystem {
        specialArgs = specialArgs;
        modules = [
          ./nixos-wsl
          ../system/base/common.nix
          ../system/nix
          inputs.ncro.nixosModules.ncro
          inputs.nixos-wsl.nixosModules.default
          inputs.home-manager.nixosModules.home-manager
          (mkHomeManager ../home/wsl.nix)
        ];
      };
    };
}
