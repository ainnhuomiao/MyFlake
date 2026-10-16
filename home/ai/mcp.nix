{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  context7Url = "https://mcp.context7.com/mcp";
  # Obsidian Local REST API 插件自带的 MCP server(Streamable HTTP)。
  # 需要 Obsidian 打开 ai-knowledge vault 且启用该插件。
  obsidianMcpUrl = "http://127.0.0.1:27123/mcp/";
  mcpNixosExe = lib.getExe pkgs.mcp-nixos;
  flakeStatsMcpExe = lib.getExe pkgs.flake-stats-mcp;
in
{
  # 公共 MCP 总线:context7 / mcp-nixos / flake-stats-mcp。
  # 不把 Obsidian(含 Bearer apiKey)写进 programs.mcp.servers——密钥来自本机
  # vault 插件 JSON,不能进 Nix store;由下方 activation 注入各客户端。
  programs.mcp = {
    enable = true;
    servers = {
      context7 = {
        url = context7Url;
        type = "http";
      };
      mcp-nixos = {
        command = mcpNixosExe;
        args = [ ];
      };
      flake-stats-mcp = {
        command = flakeStatsMcpExe;
        args = [ ];
      };
    };
  };

  # 第一波客户端:通过 enableMcpIntegration 从 programs.mcp 拉总线服务器。
  # mutableSettings=true,避免 HM 用只读 symlink 盖掉用户本地配置。
  programs.codex = {
    enable = true;
    package = pkgs.codex;
    mutableSettings = true;
    enableMcpIntegration = true;
  };

  programs.opencode = {
    enable = true;
    package = pkgs.opencode;
    mutableSettings = true;
    enableMcpIntegration = true;
  };

  programs.antigravity-cli = {
    enable = true;
    package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.antigravity-cli;
    mutableSettings = true;
    enableMcpIntegration = true;
  };

  programs.claude-code = {
    enable = true;
    package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
    mutableSettings = true;
    enableMcpIntegration = true;
  };

  # activation 只处理 HM 管不了的特例:
  # - Obsidian:apiKey 运行时从 vault 插件 data.json 读取,不能声明进 store
  # - cc-switch:SQLite 里的 context7 / codex backup,无程序私有 DB
  # - Kimi:尚无 programs.* MCP 集成,仍写用户级 ~/.kimi-code/mcp.json
  # cursor-agent:HM 没有 enableMcpIntegration,读 ~/.cursor/mcp.json。
  # 把 programs.mcp 生成的 ~/.config/mcp/mcp.json 合并进去,保留用户自己加的 server。
  home.activation.configureCursorAgentMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ -z "''${DRY_RUN:-}" ]]; then
      bus="''${XDG_CONFIG_HOME:-$HOME/.config}/mcp/mcp.json"
      target="$HOME/.cursor/mcp.json"
      if [[ -f "$bus" ]]; then
        mkdir -p "$HOME/.cursor"
        [[ -f "$target" ]] || echo '{"mcpServers":{}}' > "$target"
        tmp="$(mktemp)"
        ${pkgs.jq}/bin/jq -s '.[0] * {mcpServers: ((.[0].mcpServers // {}) + .[1].mcpServers)}' \
          "$target" "$bus" > "$tmp" && mv "$tmp" "$target"
      fi
    fi
  '';

  home.activation.configureMcpSpecials = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ -z "''${DRY_RUN:-}" ]]; then
      obsidian_data="$HOME/ai-knowledge/.obsidian/plugins/obsidian-local-rest-api/data.json"
      if [[ -f "$obsidian_data" ]]; then
        obsidian_key="$(${pkgs.jq}/bin/jq -r '.apiKey // empty' "$obsidian_data" 2>/dev/null || true)"
      else
        obsidian_key=""
      fi

      # Codex:仅 upsert [mcp_servers.obsidian];context7 等由 programs.codex + MCP 集成写入
      codex_config="$HOME/.codex/config.toml"
      ${pkgs.coreutils}/bin/mkdir -p "$HOME/.codex"
      if [[ ! -f "$codex_config" ]]; then
        ${pkgs.coreutils}/bin/touch "$codex_config"
      fi
      codex_tmp="$(${pkgs.coreutils}/bin/mktemp "$HOME/.codex/config.toml.XXXXXX")"
      ${pkgs.gawk}/bin/awk -v obsidian_url="${obsidianMcpUrl}" -v obsidian_key="$obsidian_key" '
        function write_obsidian() {
          if (!obsidian_written) {
            print "[mcp_servers.obsidian]"
            print "url = \"" obsidian_url "\""
            if (obsidian_key != "") {
              print "http_headers = { Authorization = \"Bearer " obsidian_key "\" }"
            }
            print ""
            obsidian_written = 1
          }
        }

        /^\[mcp_servers\.obsidian(\.|\])/ {
          write_obsidian()
          in_obsidian = 1
          next
        }

        /^\[/ && in_obsidian {
          in_obsidian = 0
        }

        !in_obsidian {
          print
        }

        END {
          if (!obsidian_written) {
            if (NR > 0) {
              print ""
            }
            write_obsidian()
          }
        }
      ' "$codex_config" > "$codex_tmp"
      if ${pkgs.diffutils}/bin/cmp -s "$codex_config" "$codex_tmp"; then
        ${pkgs.coreutils}/bin/rm "$codex_tmp"
      else
        ${pkgs.coreutils}/bin/chmod --reference="$codex_config" "$codex_tmp"
        ${pkgs.coreutils}/bin/mv "$codex_tmp" "$codex_config"
      fi

      # cc-switch:私有 SQLite,保持与旧脚本相同的 context7 + codex backup 同步
      cc_switch_db="$HOME/.cc-switch/cc-switch.db"
      if [[ -f "$cc_switch_db" ]]; then
        ${pkgs.sqlite}/bin/sqlite3 -cmd '.timeout 5000' "$cc_switch_db" \
          "UPDATE mcp_servers
           SET server_config = json_object(
             'type',
             'http',
             'url',
             '${context7Url}'
           )
           WHERE id = 'context7';
           UPDATE proxy_live_backup
           SET original_config = json_set(
             original_config,
             '$.config',
             CAST(readfile('$codex_config') AS TEXT)
           )
           WHERE app_type = 'codex';"
      fi

      # Antigravity:只合并 obsidian(serverUrl + 可选 Bearer);
      # context7 / mcp-nixos / flake-stats-mcp 由 programs.antigravity-cli MCP 集成负责。
      # 注意:agy 远程 MCP 键是 serverUrl,勿写成 httpUrl。
      antigravity_config_dir="$HOME/.gemini/config"
      antigravity_config="$antigravity_config_dir/mcp_config.json"
      ${pkgs.coreutils}/bin/mkdir -p "$antigravity_config_dir"
      if [[ ! -s "$antigravity_config" ]]; then
        ${pkgs.coreutils}/bin/printf '{}\n' > "$antigravity_config"
      fi
      antigravity_tmp="$(${pkgs.coreutils}/bin/mktemp \
        "$antigravity_config_dir/mcp_config.json.XXXXXX")"
      ${pkgs.jq}/bin/jq \
        --arg obsidian_url "${obsidianMcpUrl}" \
        --arg obsidian_key "$obsidian_key" \
        '.mcpServers.obsidian = ({ serverUrl: $obsidian_url }
          + (if $obsidian_key != "" then
               {
                 headers: {
                   Authorization: "Bearer " + $obsidian_key
                 }
               }
             else {} end))' \
        "$antigravity_config" > "$antigravity_tmp"
      if ${pkgs.diffutils}/bin/cmp -s "$antigravity_config" "$antigravity_tmp"; then
        ${pkgs.coreutils}/bin/rm "$antigravity_tmp"
      else
        ${pkgs.coreutils}/bin/chmod --reference="$antigravity_config" "$antigravity_tmp"
        ${pkgs.coreutils}/bin/mv "$antigravity_tmp" "$antigravity_config"
      fi

      # Kimi:无 HM MCP 集成,继续写完整用户级 mcp.json(含总线 + obsidian)
      kimi_config_dir="$HOME/.kimi-code"
      kimi_config="$kimi_config_dir/mcp.json"
      ${pkgs.coreutils}/bin/mkdir -p "$kimi_config_dir"
      if [[ ! -f "$kimi_config" ]]; then
        ${pkgs.coreutils}/bin/printf '{}\n' > "$kimi_config"
        ${pkgs.coreutils}/bin/chmod 600 "$kimi_config"
      fi
      kimi_tmp="$(${pkgs.coreutils}/bin/mktemp "$kimi_config_dir/mcp.json.XXXXXX")"
      ${pkgs.jq}/bin/jq \
        --arg context7_url "${context7Url}" \
        --arg mcp_nixos "${mcpNixosExe}" \
        --arg flake_stats_mcp "${flakeStatsMcpExe}" \
        --arg obsidian_url "${obsidianMcpUrl}" \
        --arg obsidian_key "$obsidian_key" \
        '.mcpServers = ((.mcpServers // {})
          | .context7 = { url: $context7_url }
          | .["mcp-nixos"] = {
              command: $mcp_nixos,
              args: []
            }
          | .["flake-stats-mcp"] = {
              command: $flake_stats_mcp,
              args: []
            }
          | .obsidian = ({ url: $obsidian_url }
              + (if $obsidian_key != "" then
                   {
                     headers: {
                       Authorization: "Bearer " + $obsidian_key
                     }
                   }
                 else {} end)))' \
        "$kimi_config" > "$kimi_tmp"
      if ${pkgs.diffutils}/bin/cmp -s "$kimi_config" "$kimi_tmp"; then
        ${pkgs.coreutils}/bin/rm "$kimi_tmp"
      else
        ${pkgs.coreutils}/bin/chmod --reference="$kimi_config" "$kimi_tmp"
        ${pkgs.coreutils}/bin/mv "$kimi_tmp" "$kimi_config"
      fi
    fi
  '';
}
