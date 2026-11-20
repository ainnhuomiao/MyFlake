{ inputs, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      # _module.args.pkgs 在 perSystem 模块定点求值早期就被严格需要, 此处若引用
      # inputs.self.overlays 会无限递归, 故直接 import flake/nixpkgs.nix。
      nixpkgsCfg = import ../nixpkgs.nix { inherit inputs; };
      hostConfig = inputs.self.nixosConfigurations.nixos.config;
      installedPackages =
        hostConfig.environment.systemPackages ++ hostConfig.home-manager.users.huomiao.home.packages;
      # 固定候选保留原属性名;系统/HM 按 derivation 去重,并剔除固定候选中已有的项。
      # 每个 derivation 的全部输出都会构建。
      derivationKey = package: builtins.unsafeDiscardStringContext package.drvPath;
      fixedDerivations = map derivationKey (builtins.attrValues config.packages);
      uniquePackages =
        builtins.filter (package: !(builtins.elem (derivationKey package) fixedDerivations))
          (
            builtins.map builtins.head (builtins.attrValues (builtins.groupBy derivationKey installedPackages))
          );
      installedPackageOutputs = builtins.listToAttrs (
        pkgs.lib.imap0 (index: package: {
          name = "installed-${toString index}";
          value = package;
        }) uniquePackages
      );
    in
    {
      # 统一实例化 perSystem 的 pkgs(带自有 overlay), packages/checks/dev-shells
      # 等所有 perSystem 模块共用这一个实例, 不再各自 import
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        inherit (nixpkgsCfg) overlays config;
      };

      # packages 是需要确保进入 CI 缓存候选的固定集合, 外加 disko(scripts/disko.sh 使用)。
      # CI 还会合并系统与 Home Manager 直接安装的包, 自动跳过已有缓存, 不构建完整系统。
      packages = {
        inherit (pkgs)
          bili_tui
          cc-switch
          dingtalk
          firefox-bin
          flake-stats-mcp
          herdr
          mcp-nixos
          ncro
          rayburst
          telegram-desktop
          ;
        disko = inputs.disko.packages.${system}.disko;
        noctalia = inputs.noctalia.packages.${system}.default;
        linuxqq-wayland-fix = inputs.linuxqq-wayland-fix.packages.${system}.default;
        omp-cn = inputs.oh-my-pi-cn.packages.${system}.omp;
      };

      legacyPackages.cacheOutputs = config.packages // installedPackageOutputs;
    };
}
