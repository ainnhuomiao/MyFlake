{ lib, ... }:
let
  rules = import ../../lib/proxy/rules.nix;
  officialPublicKey = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
  # priority 只在延迟差约小于 10% 时决胜，数值越小越优先。
  substituters = [
    {
      url = rules.attic.substituterUrl;
      publicKey = "ainnhuomiao:rSRSxFzka/Hu1R27mYg8TIE34+X9Vq4RA+orXAUr7U4=";
      priority = 5;
      allowHedging = false;
    }
    {
      url = "https://ainnhuomiao.cachix.org";
      publicKey = "ainnhuomiao.cachix.org-1:scMAjHS0YtCSBV0d6bbFWHDGD3BkPKuWbcfeWpqw5ck=";
      priority = 10;
    }
    {
      url = "https://nix-community.cachix.org";
      publicKey = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
      priority = 20;
    }
    {
      url = "https://cache.numtide.com";
      publicKey = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
      priority = 20;
    }
    {
      url = "https://mirrors.ustc.edu.cn/nix-channels/store/";
      publicKey = officialPublicKey;
      priority = 40;
    }
    {
      url = "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store/";
      publicKey = officialPublicKey;
      priority = 40;
    }
    {
      url = "https://mirror.sjtu.edu.cn/nix-channels/store/";
      publicKey = officialPublicKey;
      priority = 40;
    }
    {
      # 镜像同步滞后时由官方源补齐，但不为代理链路制造额外下载。
      url = "https://cache.nixos.org";
      publicKey = officialPublicKey;
      priority = 100;
      allowHedging = false;
    }
  ];
  toUpstream =
    cache:
    {
      inherit (cache) url;
      public_key = cache.publicKey;
    }
    // lib.optionalAttrs (cache ? priority) { inherit (cache) priority; }
    // lib.optionalAttrs (cache ? allowHedging) { allow_hedging = cache.allowHedging; };
in
{
  services.ncro = {
    enable = true;
    settings = {
      server = {
        listen = "127.0.0.1:5496";
        cache_priority = 10;
        want_mass_query = true;
      };
      upstreams = map toUpstream substituters;
      cache = {
        # 新包尚未同步时缩短 404 记忆时间，成功路由仍使用默认 1 小时 TTL。
        negative_ttl = "1m";
        nar_hedging = {
          enabled = true;
          delay = "1s";
          max_inflight = 2;
        };
      };
      # 正常上游全部不可用时仍尝试官方缓存。
      fallback_cache = {
        enabled = true;
        url = "https://cache.nixos.org";
        public_key = officialPublicKey;
      };
      logging.timestamps = false;
    };
  };

  nix.settings = {
    fallback = true;
    http-connections = 16;
    max-substitution-jobs = 32;
    # ncro 并行查询全部上游；公钥由其 NixOS 模块自动加入 trusted-public-keys。
    substituters = lib.mkForce [ "http://127.0.0.1:5496" ];
    trusted-users = [
      "root"
      "@wheel"
    ];
  };
}
