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
      # nixpkgs 已把 gtk2 标为 broken（计划 27.05 移除，见 #410814），而钉钉 8.x 依赖的
      # gtkglext 仍硬依赖 gtk2，不放行会直接导致求值失败。上游迁移到 gtk3 之前只能降级为警告。
      problems.handlers."gtk+".broken = "warn";
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
