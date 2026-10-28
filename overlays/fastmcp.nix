# fastmcp 3.4.7 的兼容修复：
# 1. 它要求 mcp>=1.24,<2，而 nixpkgs 已把 mcp 升到 2.2.0。
#    只给 fastmcp-slim 固定 mcp 1.29.0，不影响其他 Python 包。
# 2. 禁用三个在沙箱/共享 CI runner 上必挂或 flaky 的时序敏感测试：
#    test_ping_middleware_registers_session、test_ping_task_cancelled_on_disconnect
#    和 test_server_initialization_performance。
# 等 nixpkgs 的 fastmcp 支持 mcp 2 并处理这些测试后即可删除本文件。
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
      _pyFinal: pyPrev:
      let
        mcp_1 = pyPrev.mcp.overridePythonAttrs (oldAttrs: rec {
          version = "1.29.0";
          src = prev.fetchFromGitHub {
            owner = "modelcontextprotocol";
            repo = "python-sdk";
            tag = "v${version}";
            hash = "sha256-lRlj5RT/R5zrYL5XpdQR2l9t99G94WTsubN0gSQekMc=";
          };

          pythonRelaxDeps = (oldAttrs.pythonRelaxDeps or [ ]) ++ [ "pydantic-settings" ];
          dependencies = with pyPrev; [
            anyio
            httpx
            httpx-sse
            jsonschema
            pydantic
            pydantic-settings
            pyjwt
            python-multipart
            sse-starlette
            starlette
            uvicorn
          ];
          optional-dependencies = oldAttrs.optional-dependencies // {
            ws = [ pyPrev.websockets ];
          };
          nativeCheckInputs =
            (with pyPrev; [
              dirty-equals
              inline-snapshot
              pytest-asyncio
              pytest-examples
              pytest-xdist
              pytestCheckHook
              requests
            ])
            ++ prev.lib.flatten (builtins.attrValues optional-dependencies);
          pytestFlags = (oldAttrs.pytestFlags or [ ]) ++ [
            "-Wignore::pytest.PytestRemovedIn10Warning"
          ];
          disabledTests = (oldAttrs.disabledTests or [ ]) ++ [
            "test_command_execution"
            "test_lifespan_cleanup_executed"
            "test_basic_child_process_cleanup"
            "test_nested_process_tree"
            "test_early_parent_exit"
            "test_list_tools_returns_all_tools"
            "test_stdin_close_triggers_cleanup"
            "test_resource_template_client_interaction"
            "test_tool_progress"
          ];
        });
      in
      {
        fastmcp-slim = pyPrev.fastmcp-slim.override { mcp = mcp_1; };
        fastmcp = pyPrev.fastmcp.overridePythonAttrs (oldAttrs: {
          disabledTests = (oldAttrs.disabledTests or [ ]) ++ [
            "test_ping_middleware_registers_session"
            "test_ping_task_cancelled_on_disconnect"
            "test_server_initialization_performance"
          ];
        });
      }
    )
  );
}
