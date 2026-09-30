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
    GOPATH = goPath;
    GOMODCACHE = "${goPath}/pkg/mod";
    GO111MODULE = "on";
  };
  xdg.configFile."go/env".text = ''
    GOPATH=${goPath}
  '';
  programs.fish.interactiveShellInit = ''
    set -gx PATH $GOPATH/bin $PATH
  '';
  programs.bash.initExtra = ''
    export PATH=$GOPATH/bin:$PATH
  '';
}
