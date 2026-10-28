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
      homeProfiles = import ../home/profiles;
      specialArgs = {
        inherit inputs self me;
        appearance = import ../lib/appearance.nix;
      };
      mkHomeManager = hostName: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          extraSpecialArgs = specialArgs;
          users.${me.userName}.imports =
            homeProfiles."${me.userName}@${hostName}"
              or (throw "no home profile for ${me.userName}@${hostName}");
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
          inputs.home-manager.nixosModules.home-manager
          (mkHomeManager "nixos")
        ];
      };
    };
}
