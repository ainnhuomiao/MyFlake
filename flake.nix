{
  description = "MyFlake — huomiao's NixOS configuration";

  outputs =
    inputs@{ self, ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [
        ./flake/modules
        ./hosts
        inputs.flake-root.flakeModule
        inputs.treefmt-nix.flakeModule
      ];
    };

  inputs = {
    # update single input: `nix flake lock --update-input <name>`
    # update all inputs: `nix flake update`
    emanote = {
      url = "github:srid/emanote";
      # emanote 的 Haskell 依赖 fsnotify-0.4.1.0 要求 text < 2.1.2，
      # 故锁在 nixpkgs-emanote（6b49552），顶层 nixpkgs 可自由更新
      inputs.nixpkgs.follows = "nixpkgs-emanote";
    };
    nixpkgs-emanote.url = "github:nixos/nixpkgs/6b4955211758ba47fac850c040a27f23b9b4008f";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    flake-registry = {
      url = "github:NixOS/flake-registry";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    hyprpicker = {
      url = "github:hyprwm/hyprpicker";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      # numtide/llm-agents.nix: AI coding agent 包集 (antigravity-cli/omp/pi/kimi-code)
      # 不 follows nixpkgs: 其包只对其钉的 nixpkgs-unstable 构建测试,
      # 跟随会丢 cache.numtide.com 缓存命中且随上游 nixpkgs 更新漂移
      url = "github:numtide/llm-agents.nix";
    };
    noctalia = {
      # 不 follows nixpkgs: 其包只对自身钉的 nixpkgs-unstable 构建测试,
      # 跟随会丢 noctalia.cachix 命中且随上游 nixpkgs 更新漂移 (同 llm-agents 注释)
      url = "github:noctalia-dev/noctalia/v5.0.1";
    };
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    selector4nix = {
      url = "github:StarryReverie/selector4nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    swayfx = {
      url = "github:WillPower3309/swayfx/0.6";
      # 0.6 起才有 animation_duration_ms(窗口开合动画),nixpkgs 仍钉 0.5.3
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "git+https://github.com/youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    fallback = true;
    http-connections = 16;
    extra-substituters = [
      "https://noctalia.cachix.org"
      "https://ainnhuomiao.qianyuanqing.asia/ainnhuomiao"
      "https://ainnhuomiao.cachix.org"
      "https://nix-community.cachix.org"
      "https://attic.xuyh0120.win/lantian"
    ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "ainnhuomiao:rSRSxFzka/Hu1R27mYg8TIE34+X9Vq4RA+orXAUr7U4="
      "ainnhuomiao.cachix.org-1:scMAjHS0YtCSBV0d6bbFWHDGD3BkPKuWbcfeWpqw5ck="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
    trusted-users = [
      "root"
      "@wheel"
    ];
  };
}
