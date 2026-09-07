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
        };
      };
    in
    {
      packages = {
        inherit (pkgs)
          agy-hud
          bilibili
          bili_tui
          claude-code
          discord
          element-desktop
          fcitx5-pinyin-moegirl
          fcitx5-pinyin-zhwiki
          feishu
          flake-stats-mcp
          github-copilot-cli
          google-chrome
          hmcl
          mcp-nixos
          microsoft-edge
          motrix-next
          nordic
          obsidian
          qq
          swayfx
          steam
          thunderbird-bin
          v2rayn
          vscode
          wechat
          wemeet
          wpsoffice-cn
          ;
        # zen-browser 来自 flake input，nixpkgs 没有，需一并缓存
        zen-browser = inputs.zen-browser.packages.${system}.default;
        # noctalia 来自 flake input，nixpkgs 没有，需一并缓存
        noctalia = inputs.noctalia.packages.${system}.default;
        # reasonix/antigravity-cli 来自 numtide/llm-agents.nix input
        reasonix = inputs.llm-agents.packages.${system}.reasonix;
        antigravity-cli = inputs.llm-agents.packages.${system}.antigravity-cli;
        omp = inputs.llm-agents.packages.${system}.omp;
        pi = inputs.llm-agents.packages.${system}.pi;
      };
    };
}
