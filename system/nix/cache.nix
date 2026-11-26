{ lib, pkgs, ... }:
let
  rules = import ../network/proxy/rules.nix;
  officialPublicKey = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
  # ncro 按 priority 分组严格由小到大依次尝试：
  # 1) 国内直连镜像优先，覆盖绝大部分 nixpkgs 包且不占用代理并发；
  # 2) 官方 cache.nixos.org 紧随其后补齐镜像同步滞后；
  # 3) 个人 Attic 与第三方缓存仅在官方源未命中时查询，避免为常规 nixpkgs 包制造无效代理请求。
  substituters = [
    {
      url = "https://mirrors.ustc.edu.cn/nix-channels/store/";
      publicKey = officialPublicKey;
      priority = 10;
    }
    {
      url = "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store/";
      publicKey = officialPublicKey;
      priority = 10;
    }
    {
      url = "https://mirror.sjtu.edu.cn/nix-channels/store/";
      publicKey = officialPublicKey;
      priority = 10;
    }
    {
      # 镜像同步滞后时由官方源补齐，但不为代理链路制造额外下载。
      url = "https://cache.nixos.org";
      publicKey = officialPublicKey;
      priority = 20;
      allowHedging = false;
    }
    {
      url = rules.attic.substituterUrl;
      publicKey = "ainnhuomiao:rSRSxFzka/Hu1R27mYg8TIE34+X9Vq4RA+orXAUr7U4=";
      priority = 30;
      allowHedging = false;
    }
    {
      url = "https://nix-community.cachix.org";
      publicKey = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
      priority = 40;
    }
    {
      url = "https://cache.numtide.com";
      publicKey = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
      priority = 40;
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
    # ncro 模块用 mkDefault 指向未带 sqlite 的上游包。普通优先级换成补了 sqlite.dev 的包装。
    package = pkgs.ncro;
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
        # 限制单上游并发与冷却窗口，避免 mass-query 打爆代理节点并长时间跳过 cache.nixos.org。
        mass_query = {
          max_concurrent_races = 16;
          per_upstream_max_inflight = 4;
          upstream_cooldown = "3s";
        };
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
    # 与 ncro 的 negative_ttl = "1m" 对齐，避免瞬时 404 在 nix-daemon 负缓存中锁死 1 小时。
    narinfo-cache-negative-ttl = 60;
    http-connections = 8;
    max-substitution-jobs = 16;
    # ncro 并行查询全部上游；公钥由其 NixOS 模块自动加入 trusted-public-keys。
    substituters = lib.mkForce [ "http://127.0.0.1:5496" ];
    trusted-users = [
      "root"
      "@wheel"
    ];
  };
}
