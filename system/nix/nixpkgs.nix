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
        # 钉钉客户端自带 OpenSSL 1.1（EOL），见 pkgs/dingtalk/default.nix
        "dingtalk-8.2.8.260818002"
        "electron-39.8.10"
      ];
    };
    overlays = [
      self.overlays.default
      inputs.rust-overlay.overlays.default
    ];
  };
}
