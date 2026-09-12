{
  pkgs,
  me,
  lib,
  ...
}:

let
  userName = me.userName;
  configGroup = "mihomo-config";
  configDirectory = "/var/lib/mihomo-config";
  configFile = "${configDirectory}/config.yaml";
  subscriptionsFile = "${configDirectory}/subscriptions.yaml";
  providerDirectory = "${configDirectory}/proxy-providers";

  zashboard = pkgs.fetchzip {
    url = "https://github.com/Zephyruso/zashboard/releases/download/v3.16.0/dist.zip";
    hash = "sha256-HnbkkmDJeTE+ynvgLevWuGGRVjUlO8fIAGaPHLHxbj8=";
  };

  generateConfig = pkgs.writeShellApplication {
    name = "mihomo-generate-config";
    runtimeInputs = with pkgs; [
      coreutils
      mihomo
      yq-go
    ];
    text = ''
            umask 007

            if [[ ! -s "${subscriptionsFile}" ]]; then
              echo "Mihomo subscriptions file is missing: ${subscriptionsFile}" >&2
              exit 1
            fi

            yq eval '.subscriptions = (.subscriptions // {})' "${subscriptionsFile}" >/dev/null

            tmp_file="$(mktemp "${configDirectory}/.config.yaml.XXXXXX")"
            trap 'rm -f "$tmp_file"' EXIT

            cat > "$tmp_file" <<'YAML'
      allow-lan: false
      bind-address: 127.0.0.1
      mode: rule
      log-level: warning
      ipv6: false
      external-controller: 127.0.0.1:9090
      secret: ""
      profile:
        store-selected: true
      listeners:
        - name: dae-proxy
          type: socks
          listen: 127.0.0.1
          port: 12346
          udp: true
          proxy: DAE-PROXY
        - name: dae-mining
          type: socks
          listen: 127.0.0.1
          port: 12347
          udp: true
          proxy: DAE-MINING
      proxy-providers: {}
      proxy-groups:
        - name: DAE-PROXY
          type: select
          proxies:
            - DIRECT
        - name: DAE-MINING
          type: select
          proxies:
            - DIRECT
      rules:
        - MATCH,DIRECT
      YAML

            while IFS= read -r name; do
              [[ -n "$name" ]] || continue
              if [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
                echo "Invalid subscription name: $name" >&2
                exit 1
              fi

              url="$(SUBSCRIPTION_NAME="$name" yq eval -r '.subscriptions[strenv(SUBSCRIPTION_NAME)].url // ""' "${subscriptionsFile}")"
              if [[ -z "$url" ]]; then
                echo "Subscription URL is empty: $name" >&2
                exit 1
              fi

              provider_name="subscription-$name"
              provider_group="订阅/$name"
              provider_path="${providerDirectory}/$name.yaml"
              provider_prefix="[$name] "

              PROVIDER_NAME="$provider_name" \
                PROVIDER_URL="$url" \
                PROVIDER_GROUP="$provider_group" \
                PROVIDER_PATH="$provider_path" \
                PROVIDER_PREFIX="$provider_prefix" \
                yq eval -i '
                  .["proxy-providers"][strenv(PROVIDER_NAME)] = {
                    "type": "http",
                    "url": strenv(PROVIDER_URL),
                    "path": strenv(PROVIDER_PATH),
                    "interval": 21600,
                    "header": {"User-Agent": ["mihomo"]},
                    "exclude-filter": "(?i)剩余流量|下次重置|套餐到期|官网|Telegram|建议每天|如果很少节点|欢迎加入|IPv6",
                    "health-check": {
                      "enable": true,
                      "url": "https://cp.cloudflare.com/generate_204",
                      "interval": 1800,
                      "timeout": 5000,
                      "lazy": true
                    },
                    "override": {"additional-prefix": strenv(PROVIDER_PREFIX)}
                  } |
                  .["proxy-groups"] += [{
                    "name": strenv(PROVIDER_GROUP),
                    "type": "url-test",
                    "use": [strenv(PROVIDER_NAME)],
                    "url": "https://cp.cloudflare.com/generate_204",
                    "interval": 1800,
                    "tolerance": 100,
                    "lazy": true
                  }] |
                  .["proxy-groups"][0].proxies += [strenv(PROVIDER_GROUP)] |
                  .["proxy-groups"][1].proxies += [strenv(PROVIDER_GROUP)]
                ' "$tmp_file"
            done < <(yq eval -r '.subscriptions | keys | .[]' "${subscriptionsFile}")

            first_provider_group="$(yq eval -r '.["proxy-groups"] | map(select(.type == "url-test")) | .[0].name // ""' "$tmp_file")"
            if [[ -n "$first_provider_group" ]]; then
              PROVIDER_GROUP="$first_provider_group" yq eval -i '
                .["proxy-groups"][0].proxies = [strenv(PROVIDER_GROUP), "DIRECT"] +
                  (.["proxy-groups"][0].proxies | map(select(. != strenv(PROVIDER_GROUP) and . != "DIRECT"))) |
                .["proxy-groups"][1].proxies = [strenv(PROVIDER_GROUP), "DIRECT"] +
                  (.["proxy-groups"][1].proxies | map(select(. != strenv(PROVIDER_GROUP) and . != "DIRECT")))
              ' "$tmp_file"
            fi

            yq eval '.' "$tmp_file" >/dev/null
            mihomo -t -d "${configDirectory}" -f "$tmp_file"
            chmod 0640 "$tmp_file"
            mv -f "$tmp_file" "${configFile}"
            trap - EXIT
    '';
  };

  subscriptionManager = pkgs.writeShellApplication {
    name = "mihomo-sub";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
      systemd
      yq-go
    ];
    text = ''
            controller_url="''${MIHOMO_CONTROLLER_URL:-http://127.0.0.1:9090}"

            validate_name() {
              local name="$1"
              [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
            }

            load_subscriptions() {
              mapfile -t subscriptions < <(
                yq eval -r '.subscriptions | keys | .[]' "${subscriptionsFile}"
              )
            }

            choose_subscription() {
              load_subscriptions
              if (( ''${#subscriptions[@]} == 0 )); then
                echo "当前没有订阅"
                return 1
              fi

              printf '\n'
              for index in "''${!subscriptions[@]}"; do
                printf '%d) %s\n' "$((index + 1))" "''${subscriptions[$index]}"
              done
              printf '0) 返回\n'

              while true; do
                read -r -p "请选择订阅: " selection
                if [[ "$selection" == 0 ]]; then
                  return 1
                fi
                if [[ "$selection" =~ ^[0-9]+$ ]] &&
                  (( selection >= 1 && selection <= ''${#subscriptions[@]} )); then
                  selected_subscription="''${subscriptions[$((selection - 1))]}"
                  return 0
                fi
                echo "无效选择"
              done
            }

            wait_for_regeneration() {
              sleep 1
              if systemctl is-failed --quiet mihomo-config-regenerate.service; then
                echo "配置生成失败，原有配置未被替换" >&2
                systemctl status mihomo-config-regenerate.service --no-pager -l >&2 || true
                return 1
              fi
              if systemctl is-active --quiet mihomo.service; then
                echo "配置已生效，Mihomo 正在运行"
              else
                echo "配置已保存，但 Mihomo 未运行" >&2
                return 1
              fi
            }

            replace_store() {
              local temporary_file="$1"
              chmod 0600 "$temporary_file"
              mv -f "$temporary_file" "${subscriptionsFile}"
              wait_for_regeneration
            }

            show_subscriptions() {
              load_subscriptions
              if (( ''${#subscriptions[@]} == 0 )); then
                echo "当前没有订阅"
                return
              fi

              provider_data="$(curl --fail --silent "$controller_url/providers/proxies" || true)"
              printf '\n%-24s %s\n' "订阅" "节点数"
              printf '%-24s %s\n' "------------------------" "------"
              for name in "''${subscriptions[@]}"; do
                provider_name="subscription-$name"
                if [[ -n "$provider_data" ]]; then
                  node_count="$(jq -r --arg name "$provider_name" '.providers[$name].proxies | length // 0' <<< "$provider_data")"
                else
                  node_count="-"
                fi
                printf '%-24s %s\n' "$name" "$node_count"
              done
            }

            add_subscription() {
              read -r -p "订阅名称: " name
              if ! validate_name "$name"; then
                echo "名称只能包含字母、数字、点、下划线和连字符" >&2
                return 1
              fi

              if [[ "$(SUBSCRIPTION_NAME="$name" yq eval '.subscriptions[strenv(SUBSCRIPTION_NAME)] != null' "${subscriptionsFile}")" == true ]]; then
                read -r -p "订阅已存在，是否替换？[y/N] " confirmation
                [[ "$confirmation" =~ ^[Yy]$ ]] || return 0
              fi

              read -r -s -p "订阅 URL: " url
              printf '\n'
              if [[ ! "$url" =~ ^https?:// ]]; then
                echo "URL 必须以 http:// 或 https:// 开头" >&2
                return 1
              fi

              temporary_file="$(mktemp "${configDirectory}/.subscriptions.yaml.XXXXXX")"
              cp "${subscriptionsFile}" "$temporary_file"
              SUBSCRIPTION_NAME="$name" SUBSCRIPTION_URL="$url" \
                yq eval -i \
                  '.subscriptions[strenv(SUBSCRIPTION_NAME)].url = strenv(SUBSCRIPTION_URL)' \
                  "$temporary_file"
              replace_store "$temporary_file"
            }

            remove_subscription() {
              choose_subscription || return 0
              read -r -p "确认删除 $selected_subscription？[y/N] " confirmation
              [[ "$confirmation" =~ ^[Yy]$ ]] || return 0

              temporary_file="$(mktemp "${configDirectory}/.subscriptions.yaml.XXXXXX")"
              cp "${subscriptionsFile}" "$temporary_file"
              SUBSCRIPTION_NAME="$selected_subscription" \
                yq eval -i 'del(.subscriptions[strenv(SUBSCRIPTION_NAME)])' "$temporary_file"
              replace_store "$temporary_file"
            }

            refresh_provider() {
              local name="$1"
              local response_file http_code response_body

              response_file="$(mktemp)"
              if ! http_code="$(curl \
                --silent \
                --show-error \
                --output "$response_file" \
                --write-out '%{http_code}' \
                --request PUT \
                --max-time 20 \
                --retry 2 \
                --retry-delay 1 \
                --retry-max-time 45 \
                "$controller_url/providers/proxies/subscription-$name")"; then
                rm -f "$response_file"
                printf '刷新失败：%s（无法连接 Mihomo 控制器或请求超时；继续使用现有缓存）\n' "$name" >&2
                return 1
              fi

              if [[ ! "$http_code" =~ ^2[0-9][0-9]$ ]]; then
                response_body="$(tr '\r\n' '  ' < "$response_file")"
                response_body="''${response_body:0:300}"
                rm -f "$response_file"
                if [[ -n "$response_body" ]]; then
                  printf '刷新失败：%s（HTTP %s：%s；继续使用现有缓存）\n' \
                    "$name" "$http_code" "$response_body" >&2
                else
                  printf '刷新失败：%s（HTTP %s；继续使用现有缓存）\n' \
                    "$name" "$http_code" >&2
                fi
                return 1
              fi

              rm -f "$response_file"
              printf '已刷新：%s\n' "$name"
            }

            refresh_subscription() {
              choose_subscription || return 0
              refresh_provider "$selected_subscription" || true
            }

            refresh_all() {
              local failed=()

              load_subscriptions
              if (( ''${#subscriptions[@]} == 0 )); then
                echo "当前没有订阅"
                return
              fi

              for name in "''${subscriptions[@]}"; do
                if ! refresh_provider "$name"; then
                  failed+=("$name")
                fi
              done

              if (( ''${#failed[@]} > 0 )); then
                printf '刷新完成：%d 个成功，%d 个失败（失败订阅继续使用现有缓存）：%s\n' \
                  "$(( ''${#subscriptions[@]} - ''${#failed[@]} ))" \
                  "''${#failed[@]}" \
                  "''${failed[*]}" >&2
              else
                printf '全部 %d 个订阅刷新成功\n' "''${#subscriptions[@]}"
              fi
            }

            if [[ ! -s "${subscriptionsFile}" ]]; then
              echo "订阅配置不存在，请先重新构建 NixOS" >&2
              exit 1
            fi

            while true; do
              cat <<'EOF'

      Mihomo 订阅管理
      1) 查看订阅
      2) 添加或替换订阅
      3) 删除订阅
      4) 刷新一个订阅
      5) 刷新全部订阅
      0) 退出
      EOF
              read -r -p "请选择操作: " action
              case "$action" in
                1) show_subscriptions ;;
                2) add_subscription ;;
                3) remove_subscription ;;
                4) refresh_subscription ;;
                5) refresh_all ;;
                0) exit 0 ;;
                *) echo "无效选择" ;;
              esac
            done
    '';
  };
in
{
  services.mihomo = {
    enable = true;
    tunMode = false;
    configFile = configFile;
    webui = zashboard;
  };

  users.groups.${configGroup} = { };
  users.users.${userName}.extraGroups = [ configGroup ];

  # 默认不开机自启：不 want 任何 target。需启动时用 dae-toggle 手动开启。
  systemd.services.mihomo.wantedBy = lib.mkForce [ ];

  systemd.services.mihomo.serviceConfig = {
    SupplementaryGroups = [ configGroup ];
    ReadWritePaths = [ configDirectory ];
  };
  systemd.services.mihomo.environment.SAFE_PATHS = configDirectory;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        subject.user == "${userName}" &&
        action.id == "org.freedesktop.systemd1.manage-units" &&
        action.lookup("unit") == "mihomo.service"
      ) {
        return polkit.Result.YES;
      }
    });
  '';

  environment.systemPackages = [ subscriptionManager ];

  systemd.tmpfiles.rules = [
    "d ${configDirectory} 2770 ${userName} ${configGroup} -"
    "d ${providerDirectory} 2770 ${userName} ${configGroup} -"
  ];

  systemd.services.mihomo-config-regenerate = {
    description = "Regenerate Mihomo config after subscription changes";
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.util-linux}/bin/runuser -u ${userName} -- \
        ${generateConfig}/bin/mihomo-generate-config
      chgrp ${configGroup} "${configFile}"
      chmod 0640 "${configFile}"
      systemctl try-restart mihomo.service
    '';
  };

  systemd.paths.mihomo-config-regenerate = {
    description = "Watch Mihomo subscriptions";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = subscriptionsFile;
      Unit = "mihomo-config-regenerate.service";
    };
  };

  system.activationScripts.mihomoConfig = {
    deps = [ "users" ];
    text = ''
      install -d -o ${userName} -g ${configGroup} -m 2770 \
        "${configDirectory}" \
        "${providerDirectory}"

      chown ${userName}:${configGroup} "${subscriptionsFile}"
      chmod 0600 "${subscriptionsFile}"

      ${pkgs.util-linux}/bin/runuser -u ${userName} -- \
        ${generateConfig}/bin/mihomo-generate-config
      chgrp ${configGroup} "${configFile}"
      chmod 0640 "${configFile}"
    '';
  };
}
