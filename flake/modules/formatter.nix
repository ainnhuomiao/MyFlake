{
  perSystem =
    { config, pkgs, ... }:
    {
      treefmt.config = {
        inherit (config.flake-root) projectRootFile;
        flakeCheck = true;
        package = pkgs.treefmt;

        settings.global.excludes = [
          "*.conf"
          "*.fish"
          "*.png"
          "*secrets.yaml"
          "justfile"
          # pnpm 自己写 lockfile,prettier 重排会改变其内容,导致 pnpmDeps 哈希失配。
          "**/pnpm-lock.yaml"
          # 依赖树和工具临时目录永远不该被格式化;否则生成式 profile 一落地就会让 nix fmt 失败。
          "**/node_modules/**"
          ".tmp/**"
        ];

        programs = {
          nixfmt.enable = true;
          prettier.enable = true;
          shfmt.enable = true;
          stylua = {
            enable = true;
            settings = {
              indent_type = "Spaces";
              indent_width = 2;
            };
          };
        };
      };

      formatter = config.treefmt.build.wrapper;
    };
}
