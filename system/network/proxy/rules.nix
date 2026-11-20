let
  # flake.nix 的 nixConfig 只接受字面量，首个 substituter 是 Attic URL 的唯一来源。
  substituterUrl = builtins.head (import ../../../flake.nix).nixConfig.extra-substituters;
  domain = builtins.head (builtins.match "https://([^/]+)/.*" substituterUrl);
in
rec {
  attic = {
    inherit domain substituterUrl;
  };

  # .cc.cd 域名国内直连会触发 SNI 阻断，Attic 改走 sing-box 的 Nix 下载代理分组。
  nixDownloadDomains = [
    attic.domain
  ];

  direct = {
    domains = [
      "mirrors.ustc.edu.cn"
      "mirrors.tuna.tsinghua.edu.cn"
      "mirror.sjtu.edu.cn"
    ];
    ipCidrs = [ ];
  };
}
