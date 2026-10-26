let
  rules = import ../../lib/proxy/rules.nix;
  substituters = [
    {
      url = rules.attic.substituterUrl;
      publicKey = "ainnhuomiao:rSRSxFzka/Hu1R27mYg8TIE34+X9Vq4RA+orXAUr7U4=";
    }
    {
      url = "https://ainnhuomiao.cachix.org";
      publicKey = "ainnhuomiao.cachix.org-1:scMAjHS0YtCSBV0d6bbFWHDGD3BkPKuWbcfeWpqw5ck=";
    }
    {
      url = "https://nix-community.cachix.org";
      publicKey = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
    }
    rec {
      url = "https://cache.numtide.com";
      publicKey = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
      # Preserve selector4nix's existing trailing slash.
      selector.url = "${url}/";
    }
    {
      # USTC mirror of cache.nixos.org; higher priority = lower precedence
      url = "https://mirrors.ustc.edu.cn/nix-channels/store/";
      selectorOnly = true;
      selector.priority = 45;
    }
  ];
  nixSubstituters = builtins.filter (cache: !(cache.selectorOnly or false)) substituters;
in
{
  # selector4nix: local substituter proxy with latency-aware selection
  # It prepends itself to the substituter list; upstream fallbacks stay intact.
  services.selector4nix = {
    enable = true;
    enablePersistentCaching = true;
    # "prepend": proxy first, original substituters as fallback (safe if proxy dies)
    configureSubstituter = "prepend";

    settings = {
      server = {
        ip = "127.0.0.1";
        # port = 5496; # Default port
      };

      # NOTE: cache.nixos.org deliberately NOT an upstream — sing-box routes it
      # (non-geosite:cn) through the proxy node, where it is intermittently
      # dead/throttled (33KB/s-6.5MB/s measured 2026-09-04); USTC below
      # mirrors its content and goes direct (geosite:cn). Direct
      # cache.nixos.org remains in nix.settings.substituters as a last-resort
      # fallback (NixOS appends it by default).
      substituters = map (cache: { inherit (cache) url; } // (cache.selector or { })) substituters;
    };
  };

  nix.settings = {
    fallback = true;
    http-connections = 16;
    max-substitution-jobs = 32;
    substituters = map (cache: cache.url) nixSubstituters;
    trusted-public-keys = map (cache: cache.publicKey) nixSubstituters;
    trusted-users = [
      "root"
      "@wheel"
    ];
  };
}
