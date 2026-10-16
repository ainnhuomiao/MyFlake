{ inputs }:
{
  overlay = final: prev: {
    agy-hud = final.callPackage ./agy-hud { };
    bili_tui = final.callPackage ./bili_tui { };
    dingtalk = final.callPackage ./dingtalk { };
    # 参数名与包名相同: 显式传入 prev(nixpkgs) 版本, 否则 callPackage 会解析到 final 自身造成无限递归
    fcitx5-pinyin-zhwiki = final.callPackage ./fcitx5-pinyin-zhwiki {
      fcitx5-pinyin-zhwiki = prev.fcitx5-pinyin-zhwiki;
    };
    flake-stats-mcp = final.callPackage ./flake-stats-mcp { };
    herdr = inputs.herdr.packages.${final.stdenv.hostPlatform.system}.default;
    omp-provider = final.callPackage ./omp-provider { };
  };
}
