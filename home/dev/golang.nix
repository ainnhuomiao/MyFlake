{ config, pkgs, ... }:
let
  goPath = "${config.home.homeDirectory}/Codelearning/go";
in
{
  home.packages = with pkgs; [
    go
    graphviz
    protobuf
    protoc-gen-go
    protoc-gen-go-grpc
    grpcurl
  ];

  home.sessionVariables = {
    GOMODCACHE = "${goPath}/pkg/mod";
    GO111MODULE = "on";
  };
  # GOPATH 只写 go/env(go 工具链自读); bin 目录走 sessionPath,
  # 不在 interactiveShellInit 里叠加(每个交互 shell 会重复 prepend)
  home.sessionPath = [ "${goPath}/bin" ];
  xdg.configFile."go/env".text = ''
    GOPATH=${goPath}
  '';
}
