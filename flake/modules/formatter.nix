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
