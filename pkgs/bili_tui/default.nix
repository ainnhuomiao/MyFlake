{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "bilibili_live_tui";
  # 上游无版本号, 按 nixpkgs 规范用 0-unstable-<commit 日期>
  version = "0-unstable-2024-12-02";

  src = fetchFromGitHub {
    owner = "yaocccc";
    repo = pname;
    rev = "06c76edde4051081e57beb19f46fb7bce365b176";
    sha256 = "sha256-uafKRsCvF/i4TDzdMTm+iYOowavAdUUUtjuFrrR36IY=";
  };

  vendorHash = "sha256-B0MWQGtxKKc02dxIS6jWkK120/tdD/Ow3LSKklBmLnw=";

  subPackages = [ "." ];

  ldflags = [
    "-w"
    "-s"
  ];

  # 上游仓库(yaocccc/bilibili_live_tui)无 LICENSE 文件, 故 meta 不标注 license
  meta = with lib; {
    description = "终端下使用的bilibili弹幕获取和弹幕发送服务";
    homepage = "https://github.com/yaocccc/bilibili_live_tui";
    mainProgram = "bili";
    platforms = platforms.linux;
  };
}
