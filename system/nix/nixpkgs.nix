{
  self,
  inputs,
  ...
}:
{
  nixpkgs = {
    config = {
      allowBroken = true;
      allowUnsupportedSystem = true;
      allowUnfree = true;
      permittedInsecurePackages = [
        # 钉钉客户端自带 OpenSSL 1.1（EOL），见 pkgs/dingtalk/default.nix; 版本号单一来源 pkgs/dingtalk/version.nix
        "dingtalk-${import ../../pkgs/dingtalk/version.nix}"
      ];
    };
    overlays = [
      self.overlays.default
      inputs.rust-overlay.overlays.default
    ];
  };
}
