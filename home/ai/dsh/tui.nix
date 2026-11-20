# dsh-TUI:一个自带 cordis.patch.yml 的 bundle 型插件(95 个 npm 包)。
# 上游:https://github.com/ccch1mneyyy/dsh-TUI
#
# 依赖清单与 lockfile 放在 ./tui/,是版本与依赖树的单一事实源;
# 升级流程:改 package.json 里的版本 -> 在该目录跑 pnpm install 刷新
# pnpm-lock.yaml -> 用假哈希构建一次换出新的 pnpmDepsHash。
#
# MCP 服务器不在这里重复定义:直接消费 home/ai/mcp.nix 的
# programs.mcp.servers,换成 @deepseek-ai/dsh-mcp-client 的 patch 行。
# 加/改 MCP 服务器只动 mcp.nix,codex、kimi、omp、DSH 一起跟着走。
{ config, lib, ... }:
let
  # DSH 要求 serverName 匹配 [A-Za-z0-9_-]{1,32};显示名尽量去掉 mcp- 前后缀,
  # 否则模型看到的是 mcp__mcp-nixos__nix 这种叠词。
  serverNameOf =
    name:
    let
      stripped = lib.removePrefix "mcp-" (lib.removeSuffix "-mcp" name);
      cleaned = builtins.replaceStrings [ "." "/" "@" " " ] [ "-" "-" "-" "-" ] (
        if stripped == "" then name else stripped
      );
    in
    lib.strings.substring 0 32 cleaned;

  # 只处理真正可用的服务器:显式关掉、或既没有 url 也没有 command 的跳过。
  usable = lib.filterAttrs (
    _: server:
    (server.enabled or true) != false
    && ((server.url or null) != null || (server.command or null) != null)
  ) config.programs.mcp.servers;

  toRow =
    name: server:
    let
      serverName = serverNameOf name;
      isHttp = (server.url or null) != null;
      headers = server.headers or { };
      env = server.env or { };
    in
    {
      id = "mcp-${serverName}";
      specifier = "@deepseek-ai/dsh-mcp-client";
      config = {
        inherit serverName;
      }
      // (
        if isHttp then
          {
            transport = "streamable-http";
            inherit (server) url;
          }
          // lib.optionalAttrs (headers != { }) { inherit headers; }
        else
          {
            transport = "stdio";
            inherit (server) command;
            args = server.args or [ ];
          }
          // lib.optionalAttrs (env != { }) { inherit env; }
      );
    };
in
{
  programs.dsh.profiles.dsh-tui = {
    pnpm = {
      dir = ./tui;
      pnpmDepsHash = "sha256-jFW92yazx/RuyZHjtQdED/ReWvSqB7H4ggGIw3rNI60=";
    };

    plugins = lib.mapAttrsToList toRow usable;

    # 依赖树由 Nix 固定,运行期 `dsh plugin` 的改动会在下次激活时被覆盖。
    # 需要彻底禁掉插件管理入口时,再加:
    #   disables = [ "plugin-manager" "tool-plugin-manager" ];
  };
}
