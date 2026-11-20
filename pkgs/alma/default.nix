# Alma (yetone) — herdr 的 GUI 客户端, 官方 AppImage 重新打包。
# 版本更新核对: https://github.com/yetone/alma-releases/releases
{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
  desktop-file-utils,
}:
let
  pname = "alma";
  version = "0.4.722";

  src = fetchurl {
    url = "https://github.com/yetone/alma-releases/releases/download/v${version}/alma-${version}-linux-x86_64.AppImage";
    hash = "sha256-SS3jC3k4E3bZij2TbZ7BZa3FUnsfoRrXiBpCDGHkRWg=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [
    makeWrapper
    desktop-file-utils
  ];

  # Alma 驱动 herdr 里的编码 agent, 内置终端/子 agent 需要这些命令。
  extraPkgs = pkgs: [
    pkgs.util-linux
    pkgs.procps
    pkgs.ripgrep
  ];

  extraInstallCommands = ''
    # Wayland 下跟随 niri 的 IME / ozone 后端, 与 kimi-code-desktop 一致。
    wrapProgram $out/bin/${pname} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-wayland-ime=true --wayland-text-input-version=3}}"

    install -Dm644 ${appimageContents}/alma.desktop \
      $out/share/applications/alma.desktop
    substituteInPlace $out/share/applications/alma.desktop \
      --replace-fail "Exec=alma %U" "Exec=$out/bin/${pname} %U"
    desktop-file-validate $out/share/applications/alma.desktop

    install -Dm644 ${appimageContents}/alma-256x256.png \
      $out/share/icons/hicolor/256x256/apps/alma.png
    install -Dm644 ${appimageContents}/alma-512x512.png \
      $out/share/icons/hicolor/512x512/apps/alma.png
  '';

  meta = {
    description = "GUI client for herdr coding agents";
    homepage = "https://alma.now";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
