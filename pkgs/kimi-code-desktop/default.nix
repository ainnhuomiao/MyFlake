# Kimi Code Desktop 官方 AppImage；更新版本时同时核对官方更新清单：
# https://code.kimi.com/kimi-code/desktop/latest-linux.yml
{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
  desktop-file-utils,
}:
let
  pname = "kimi-code-desktop";
  version = "1.1.4";

  src = fetchurl {
    url = "https://code.kimi.com/kimi-code/desktop/binaries/${version}/KimiCode-${version}-linux-x86_64.AppImage";
    hash = "sha256-D005MlQ/aOoxLqE79zMawz3/NmS/yW9O1F4vuQF73n4=";
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

  # AppRun 用 unshare 检查沙箱；内置终端调用 /bin/ps，Agent 需要 rg。
  extraPkgs = pkgs: [
    pkgs.util-linux
    pkgs.procps
    pkgs.ripgrep
  ];

  extraInstallCommands = ''
    wrapProgram $out/bin/${pname} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-wayland-ime=true --wayland-text-input-version=3}}"

    # 保留官方 desktop 文件名与 URI scheme，供 OAuth 和 CLI 打开项目使用。
    install -Dm644 ${appimageContents}/kimi-code.desktop \
      $out/share/applications/kimi-code.desktop
    substituteInPlace $out/share/applications/kimi-code.desktop \
      --replace-fail "Exec=AppRun" "Exec=$out/bin/${pname}"
    desktop-file-validate $out/share/applications/kimi-code.desktop

    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';

  meta = {
    description = "Official Kimi Code desktop client";
    homepage = "https://www.kimi.com/code";
    changelog = "https://www.kimi.com/code/docs/en/kimi-code-desktop/changelog.html";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
