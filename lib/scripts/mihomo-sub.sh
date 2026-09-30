controller_url="${MIHOMO_CONTROLLER_URL:-http://127.0.0.1:9090}"

validate_name() {
  local name="$1"
  [[ $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

load_subscriptions() {
  mapfile -t subscriptions < <(
    yq eval -r '.subscriptions | keys | .[]' "${subscriptionsFile}"
  )
}

choose_subscription() {
  load_subscriptions
  if ((${#subscriptions[@]} == 0)); then
    echo "当前没有订阅"
    return 1
  fi

  printf '\n'
  for index in "${!subscriptions[@]}"; do
    printf '%d) %s\n' "$((index + 1))" "${subscriptions[$index]}"
  done
  printf '0) 返回\n'

  while true; do
    read -r -p "请选择订阅: " selection
    if [[ $selection == 0 ]]; then
      return 1
    fi
    if [[ $selection =~ ^[0-9]+$ ]] &&
      ((selection >= 1 && selection <= ${#subscriptions[@]})); then
      selected_subscription="${subscriptions[$((selection - 1))]}"
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
  if ((${#subscriptions[@]} == 0)); then
    echo "当前没有订阅"
    return
  fi

  provider_data="$(curl --fail --silent "$controller_url/providers/proxies" || true)"
  printf '\n%-24s %s\n' "订阅" "节点数"
  printf '%-24s %s\n' "------------------------" "------"
  for name in "${subscriptions[@]}"; do
    provider_name="subscription-$name"
    if [[ -n $provider_data ]]; then
      node_count="$(jq -r --arg name "$provider_name" '.providers[$name].proxies | length // 0' <<<"$provider_data")"
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
    [[ $confirmation =~ ^[Yy]$ ]] || return 0
  fi

  read -r -s -p "订阅 URL: " url
  printf '\n'
  if [[ ! $url =~ ^https?:// ]]; then
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
  [[ $confirmation =~ ^[Yy]$ ]] || return 0

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

  if [[ ! $http_code =~ ^2[0-9][0-9]$ ]]; then
    response_body="$(tr '\r\n' '  ' <"$response_file")"
    response_body="${response_body:0:300}"
    rm -f "$response_file"
    if [[ -n $response_body ]]; then
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
  if ((${#subscriptions[@]} == 0)); then
    echo "当前没有订阅"
    return
  fi

  for name in "${subscriptions[@]}"; do
    if ! refresh_provider "$name"; then
      failed+=("$name")
    fi
  done

  if ((${#failed[@]} > 0)); then
    printf '刷新完成：%d 个成功，%d 个失败（失败订阅继续使用现有缓存）：%s\n' \
      "$((${#subscriptions[@]} - ${#failed[@]}))" \
      "${#failed[@]}" \
      "${failed[*]}" >&2
  else
    printf '全部 %d 个订阅刷新成功\n' "${#subscriptions[@]}"
  fi
}

if [[ ! -s ${subscriptionsFile} ]]; then
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
