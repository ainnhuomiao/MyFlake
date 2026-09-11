{ inputs }:
{
  overlay = final: prev: {
    agy-hud = final.callPackage ./agy-hud { };
    bili_tui = final.callPackage ./bili_tui { };
    fcitx5-pinyin-moegirl = final.callPackage ./fcitx5-pinyin-moegirl { };
    fcitx5-pinyin-zhwiki = final.callPackage ./fcitx5-pinyin-zhwiki { };
    flake-stats-mcp = final.callPackage ./flake-stats-mcp { };
    nordic = final.callPackage ./nordic { };
    # swayfx 0.6(窗口开合动画),nixpkgs 仍钉 0.5.3;复用 nixpkgs 的 sway wrapper
    swayfx = prev.sway.override {
      sway-unwrapped = inputs.swayfx.packages.${final.stdenv.hostPlatform.system}.swayfx-unwrapped-git;
    };
  };
}
