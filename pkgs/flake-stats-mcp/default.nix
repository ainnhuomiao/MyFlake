{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "flake-stats-mcp";
  version = "1.0.0";

  src = ./.;

  # 纯 stdlib 无第三方依赖:当前 nixpkgs 的 buildGoModule 对空 vendor 目录
  # 要求 vendorHash = null(无需下载依赖,也不需 hash 校验,离线可复现)
  vendorHash = null;

  meta = with lib; {
    description = "一个简单的 NixOS Flake 概览统计 MCP Server，用于演示 AI 工具扩展。";
    homepage = "https://github.com/ainnhuomiao/MyFlake";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    mainProgram = "flake-stats-mcp";
  };
}
