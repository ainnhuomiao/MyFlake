{ inputs, pkgs, ... }:
let
  zen-pkgs = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system};
  # zen 官方重发了 1.24b 的 release tarball，当前锁定的上游
  # sources.json 仍是旧哈希，导致 fixed-output 校验失败。
  # 这里覆盖为官方 URL 当前实际内容的哈希；上游跟进后可移除。
  zen-browser = zen-pkgs.zen-browser.override {
    zen-browser-unwrapped = zen-pkgs.zen-browser-unwrapped.override {
      hash = "sha256-Mj8mguc+OCR6UfvMdeVijtK7m0BNsAz5zxavMpqRb64=";
    };
  };
in
{
  home.packages = with pkgs; [
    bili_tui
    bilibili
    piliplus
    google-chrome
    dbeaver-bin
    discord
    microsoft-edge
    thunderbird-bin
    gdu
    openssl
    imv
    swayimg
    kooha
    kimi-code-desktop
    rayburst
    obsidian
    splayer-next
    kdePackages.kdenlive
    wl-screenrec
    wl-clipboard
    wpsoffice-cn
    zen-browser
  ];
}
