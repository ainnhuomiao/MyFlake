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
      # inputs.self.overlays 会无限递归, 故把 overlays.nix 的组合直接展开复刻
      overlay = inputs.nixpkgs.lib.composeManyExtensions (
        [ (import ../../pkgs { inherit inputs; }).overlay ] ++ import ../../overlays
      );
      hostConfig = inputs.self.nixosConfigurations.nixos.config;
      installedPackages =
        hostConfig.environment.systemPackages ++ hostConfig.home-manager.users.huomiao.home.packages;
      installedPackageOutputs = builtins.listToAttrs (
        pkgs.lib.imap0 (index: package: {
          name = "installed-${toString index}";
          value = package;
        }) installedPackages
      );
    in
    {
      # 统一实例化 perSystem 的 pkgs(带自有 overlay), packages/checks/dev-shells
      # 等所有 perSystem 模块共用这一个实例, 不再各自 import
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ overlay ];
        # 与系统配置一致：允许 unfree / broken / unsupported 包
        config = {
          allowUnfree = true;
          allowBroken = true;
          allowUnsupportedSystem = true;
          # gtk2 已被 nixpkgs 标为 broken，钉钉依赖的 gtkglext 仍需它，与 system/nix/nixpkgs.nix 保持一致
          problems.handlers."gtk+".broken = "warn";
          # 钉钉自带 OpenSSL 1.1（EOL），与 system/nix/nixpkgs.nix 保持一致
          permittedInsecurePackages = [ "dingtalk-${import ../../pkgs/dingtalk/version.nix}" ];
        };
      };

      # packages 是需要确保进入 CI 缓存候选的固定集合, 外加 disko(lib/scripts/disko.sh 使用)。
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
          rayburst
          telegram-desktop
          ;
        disko = inputs.disko.packages.${system}.disko;
        noctalia = inputs.noctalia.packages.${system}.default;
        hyprpicker = inputs.hyprpicker.packages.${system}.hyprpicker;
        linuxqq-wayland-fix = inputs.linuxqq-wayland-fix.packages.${system}.default;
        ncro = inputs.ncro.packages.${system}.default;
        omp-cn = inputs.oh-my-pi-cn.packages.${system}.omp;
      };

      legacyPackages.cacheOutputs = config.packages // installedPackageOutputs;
    };
}
