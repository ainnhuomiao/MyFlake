{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      # _module.args.pkgs 在 perSystem 模块定点求值早期就被严格需要, 此处若引用
      # inputs.self.overlays 会无限递归, 故把 overlays.nix 的组合直接展开复刻
      overlay = inputs.nixpkgs.lib.composeManyExtensions (
        [ (import ../../pkgs { inherit inputs; }).overlay ] ++ import ../../overlays
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
          # 钉钉自带 OpenSSL 1.1（EOL），与 system/nix/nixpkgs.nix 保持一致
          permittedInsecurePackages = [ "dingtalk-${import ../../pkgs/dingtalk/version.nix}" ];
        };
      };

      # 对外 packages 只含 CI 预构建、推 attic 的集合(见 .github/workflows/nix.yml): 上游无二进制缓存
      # 需本机编译的包, 以及固定版本的 firefox-bin(钉死 154 的重打包产物, 同样推缓存), 外加 disko
      # (lib/scripts/disko.sh 用 `nix run .#disko`)。
      # `nix flake check` 求值所有输出并构建 checks, 不构建 packages; CI 按上述 workflow
      # 的显式列表构建并上传缓存, 不构建完整系统。unfree 厂商包 / llm-agents / zen-browser 等
      # 经 overlay 或模块直接引用进入 nixosConfigurations, 本机 `just build` 仍会构建完整系统闭包。
      packages = {
        inherit (pkgs)
          bili_tui
          dingtalk
          firefox-bin
          flake-stats-mcp
          herdr
          mcp-nixos
          rayburst
          v2rayn
          ;
        disko = inputs.disko.packages.${system}.disko;
        noctalia = inputs.noctalia.packages.${system}.default;
        hyprpicker = inputs.hyprpicker.packages.${system}.hyprpicker;
        linuxqq-wayland-fix = inputs.linuxqq-wayland-fix.packages.${system}.default;
        selector4nix = inputs.selector4nix.packages.${system}.default;
      };
    };
}
