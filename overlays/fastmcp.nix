# fastmcp 3.4.7: 禁用沙箱里必挂的时序敏感测试。
# 背景: nixpkgs 4e4b0e1 上 fastmcp(3.4.7) 有两个时序敏感测试在 nix 构建
# 沙箱/共享 CI runner 上必挂或必 flaky, 拖垮 mcp-nixos 及整个 home-manager
# generation:
# 1. tests/server/middleware/test_ping.py::TestPingMiddlewareIntegration::
#    test_ping_task_cancelled_on_disconnect 报 mcp.shared.exceptions.McpError:
#    Connection closed(5785 passed, 1 failed)。
# 2. tests/server/providers/openapi/test_performance_comparison.py::
#    TestPerformance::test_server_initialization_performance 断言服务初始化
#    <200ms, 共享 runner 上实测 0.37s(5784 passed, 1 failed)。
# 二者与 nixpkgs 在本包已禁用的一批 "Timing-sensitive and flaky" 同类;
# 上游 master 同版尚未处理, 这里先本地禁用, 等上游在 default.nix 里禁用后
# 即可删除本文件。
# 注意: 不能只 overlay top-level 的 mcp-nixos —— fastmcp 经由
# python3Packages 作用域传入, 必须 overrideScope 改包集本身。
# 注意: 只能 shadow python3Packages 这一个名字。当前 nixpkgs 里
# python3Packages = dontRecurseIntoAttrs python314Packages, 且 all-packages.nix
# 函数体是 `with pkgs`(final fixed point, 含 overlay 结果), 若同时重定义两个
# 名字、且其中一个源自 prev.python3Packages, 两个名字会经由 final 互相引用
# → infinite recursion(systemd-minimal-libs 的 buildPackages python 经
# splicing 强制触发)。mcp-nixos 等消费方都经 callPackage 从 final 取
# python3Packages, 只 patch 它即全覆盖; 且该名字不随解释器版本
# (3.14→3.15)漂移, python314Packages 则会。
final: prev:

{
  python3Packages = prev.lib.dontRecurseIntoAttrs (
    prev.python3Packages.overrideScope (
      _pyFinal: pyPrev: {
        fastmcp = pyPrev.fastmcp.overridePythonAttrs (oldAttrs: {
          disabledTests = (oldAttrs.disabledTests or [ ]) ++ [
            "test_ping_task_cancelled_on_disconnect"
            "test_server_initialization_performance"
          ];
        });
      }
    )
  );
}
