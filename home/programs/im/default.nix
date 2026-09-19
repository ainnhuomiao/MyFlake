{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      telegram-desktop
      (pkgs.symlinkJoin {
        name = "wechat";
        paths = [ pkgs.wechat ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          # wayland 原生: xcb 在 scale 1.25 下经 XWayland 渲染模糊
          wrapProgram $out/bin/wechat \
            --set QT_QPA_PLATFORM wayland \
            --set QT_IM_MODULE fcitx \
            --set GTK_IM_MODULE fcitx \
            --set XMODIFIERS @im=fcitx
        '';
      })

      # QQ (Electron): 包装自带 --ozone-platform-hint=auto 且命令行优先于环境变量,
      # 必须显式 --ozone-platform=wayland 才能走 Wayland 原生 (XWayland 1.25 下模糊)
      # 用 symlinkJoin 保留原包 .desktop/图标(同 wechat), 再 wrapProgram 加 wayland 标志
      (pkgs.symlinkJoin {
        name = "qq";
        paths = [ pkgs.qq ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/qq \
            --add-flags "--ozone-platform=wayland"
          # symlinkJoin 的 qq.desktop 是指向只读 store 的符号链接, substituteInPlace 无法写入;
          # 先按目标内容复制成普通文件, 替换 Exec 为 wrapped bin 后再移回
          cp -L $out/share/applications/qq.desktop $out/share/applications/qq.desktop.tmp
          substituteInPlace $out/share/applications/qq.desktop.tmp \
            --replace-fail "${pkgs.qq}/bin/qq" "$out/bin/qq"
          mv -f $out/share/applications/qq.desktop.tmp $out/share/applications/qq.desktop
        '';
      })

      (feishu.override {
        nss = nss_latest; # Fix issue where Feishu documents cannot be opened due to NSS version mismatch
      })
      wemeet
      # 钉钉: 官方 deb 重打包 (nixpkgs 无此包), 见 pkgs/dingtalk/default.nix
      # 配方保留 deb 自带 OpenSSL 1.1 → 依赖 permittedInsecurePackages(system/nix/nixpkgs.nix)
      # wrapper 强制 QT_QPA_PLATFORM=xcb (走 XWayland), 1.25 缩放下不如 wayland 原生清晰
      dingtalk
      # nur.repos.linyinfeng.icalingua-plus-plus
      vesktop
      (element-desktop.override {
        commandLineArgs = "--enable-features=UseOzonePlatform --ozone-platform=x11";
      })
    ];
  };
}
