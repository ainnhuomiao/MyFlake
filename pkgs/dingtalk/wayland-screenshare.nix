# 钉钉 Wayland 屏幕共享 hook（LD_PRELOAD，仅注入 dingtalk 进程）。
# 上游：github.com/lzl200110/dingtalk-wayland-screenshare（MIT，submodule stb 为 public domain）。
{
  fetchFromGitHub,
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  libsForQt5,
  libportal,
  pipewire,
  opencv,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxtst,
}:
let
  pname = "dingtalk-wayland-screenshare";
  version = "e15063310eb3251e4619345c8fad0059e8a0558a";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "lzl200110";
    repo = "dingtalk-wayland-screenshare";
    rev = version;
    fetchSubmodules = true;
    hash = "sha256-yCTb1gy6gzy1WzcetrRAsoG77ST1yf+zKtTD3fojKRw=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ];

  buildInputs = [
    libsForQt5.qtbase
    libsForQt5.qtx11extras
    libportal
    pipewire
    opencv
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxtst
  ];

  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp libdingtalkhook.so $out/lib/

    runHook postInstall
  '';

  meta = {
    description = "DingTalk screen sharing implementation under Wayland";
    homepage = "https://github.com/lzl200110/dingtalk-wayland-screenshare";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "dingtalk";
  };
}
