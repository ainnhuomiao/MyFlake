{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ inputs.self.overlays.default ];
        # 与系统配置一致：允许 unfree / broken / unsupported 包
        config = {
          allowUnfree = true;
          allowBroken = true;
          allowUnsupportedSystem = true;
          # 钉钉自带 OpenSSL 1.1（EOL），与 system/nix/nixpkgs.nix 保持一致
          permittedInsecurePackages = [ "dingtalk-8.2.8.260818002" ];
        };
      };
    in
    {
      packages = {
        inherit (pkgs)
          agy-hud
          bilibili
          bili_tui
          dingtalk
          discord
          element-desktop
          fcitx5-pinyin-moegirl
          fcitx5-pinyin-zhwiki
          feishu
          flake-stats-mcp
          google-chrome
          herdr
          hmcl
          mcp-nixos
          microsoft-edge
          motrix-next
          obsidian
          omp-provider
          qq
          swayfx
          steam
          thunderbird-bin
          v2rayn
          vscode
          wl-screenrec
          wechat
          wemeet
          wpsoffice-cn
          ;
        # zen-browser 来自 flake input，nixpkgs 没有，需一并缓存
        zen-browser = inputs.zen-browser.packages.${system}.default;
        # noctalia 来自 flake input，nixpkgs 没有，需一并缓存
        noctalia = inputs.noctalia.packages.${system}.default;
        # antigravity-cli/kimi-code 来自 numtide/llm-agents.nix input
        antigravity-cli = inputs.llm-agents.packages.${system}.antigravity-cli;
        omp = inputs.llm-agents.packages.${system}.omp;
        pi = inputs.llm-agents.packages.${system}.pi;
        kimi-code = inputs.llm-agents.packages.${system}.kimi-code;
        # 以下包来自 flake input 且上游无二进制缓存(必须本机源码编译),
        # 导出后 CI 才能构建它们进 attic(见 .github/workflows/nix.yml)
        hyprpicker = inputs.hyprpicker.packages.${system}.hyprpicker;
        linuxqq-wayland-fix = inputs.linuxqq-wayland-fix.packages.${system}.default;
        selector4nix = inputs.selector4nix.packages.${system}.default;
      };
    };
}
