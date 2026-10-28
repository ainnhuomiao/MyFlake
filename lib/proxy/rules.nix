let
  # flake.nix 的 nixConfig 只接受字面量，首个 substituter 是 Attic URL 的唯一来源。
  substituterUrl = builtins.head (import ../../flake.nix).nixConfig.extra-substituters;
  domain = builtins.head (builtins.match "https://([^/]+)/.*" substituterUrl);
in
rec {
  attic = {
    inherit domain substituterUrl;
    ipv4 = "43.153.152.12";
  };

  direct = {
    domains = [
      attic.domain
      "mirrors.ustc.edu.cn"
      "mirrors.tuna.tsinghua.edu.cn"
      "mirror.sjtu.edu.cn"
    ];
    ipCidrs = [ "${attic.ipv4}/32" ];
  };
}
