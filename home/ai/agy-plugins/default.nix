# Antigravity CLI (`agy`) 声明式插件集：
#   - superpowers: 工程方法论技能套件 (brainstorming / planning / TDD / debugging / review)
#   - rtk:         PreToolUse 透明重写压缩冗长命令输出，节省 60-90% token
#   - safety-guard: PreToolUse 危险命令拦截器（在 always-proceed 下强制二次确认）
{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  superpowersPlugin = pkgs.runCommandLocal "agy-plugin-superpowers" { } ''
    if [ ! -f "${inputs.superpowers}/.antigravity-plugin/plugin.json" ] || [ ! -d "${inputs.superpowers}/skills" ]; then
      echo "superpowers input 缺少 .antigravity-plugin/plugin.json 或 skills/" >&2
      exit 1
    fi

    mkdir -p "$out/assets"
    cp "${inputs.superpowers}/.antigravity-plugin/plugin.json" "$out/plugin.json"
    cp -a "${inputs.superpowers}/skills" "$out/skills"
    cp "${inputs.superpowers}/assets/antigravity-logo.png" "$out/assets/antigravity-logo.png"
    cp "${inputs.superpowers}/LICENSE" "$out/LICENSE"
  '';

  rtkPlugin =
    pkgs.runCommandLocal "agy-plugin-rtk"
      {
        passAsFile = [
          "pluginJson"
          "hooksJson"
        ];
        pluginJson = builtins.toJSON {
          name = "rtk";
          version = pkgs.rtk.version;
          description = "Antigravity plugin for transparent command rewriting and token optimization using rtk";
          author = {
            name = "rtk-ai";
            url = "https://github.com/rtk-ai/rtk";
          };
          homepage = "https://github.com/rtk-ai/rtk";
          repository = "https://github.com/rtk-ai/rtk";
        };
        hooksJson = builtins.toJSON {
          rtk-rewrite = {
            enabled = true;
            PreToolUse = [
              {
                matcher = "run_command";
                hooks = [
                  {
                    type = "command";
                    command = "${lib.getExe pkgs.rtk} hook antigravity";
                    timeout = 10;
                  }
                ];
              }
            ];
          };
        };
      }
      ''
        mkdir -p "$out/rules"
        cp "$pluginJsonPath" "$out/plugin.json"
        cp "$hooksJsonPath" "$out/hooks.json"
        cp "${./rtk-awareness.md}" "$out/rules/AGENTS.md"
      '';

  safetyGuardPlugin =
    pkgs.runCommandLocal "agy-plugin-safety-guard"
      {
        passAsFile = [
          "pluginJson"
          "hooksJson"
        ];
        pluginJson = builtins.toJSON {
          name = "safety-guard";
          version = "1.0.0";
          description = "PreToolUse safety guardrail that forces confirmation on destructive shell, git, and NixOS commands";
          author = {
            name = "huomiao";
          };
        };
        hooksJson = builtins.toJSON {
          safety-guard = {
            enabled = true;
            PreToolUse = [
              {
                matcher = "run_command";
                hooks = [
                  {
                    type = "command";
                    command = "${lib.getExe pkgs.jq} -c -f ${./safety-guard.jq}";
                    timeout = 5;
                  }
                ];
              }
            ];
          };
        };
      }
      ''
        mkdir -p "$out"
        cp "$pluginJsonPath" "$out/plugin.json"
        cp "$hooksJsonPath" "$out/hooks.json"
      '';
in
{
  # 提供 rtk 命令（rtk gain / rtk discover / rtk bypass 及重写后的指令运行）
  home.packages = [ pkgs.rtk ];

  # 使用 recursive = true 保持 ~/.gemini/config/plugins/ 为真实可写目录，
  # 允许用户日后继续通过 `agy plugin install` 安装其它插件，同时避免 Go 目录遍历符号链接边界问题。
  home.file = {
    ".gemini/config/plugins/superpowers" = {
      source = superpowersPlugin;
      recursive = true;
    };
    ".gemini/config/plugins/rtk" = {
      source = rtkPlugin;
      recursive = true;
    };
    ".gemini/config/plugins/safety-guard" = {
      source = safetyGuardPlugin;
      recursive = true;
    };
  };
}
