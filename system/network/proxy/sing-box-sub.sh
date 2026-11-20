controller_url="${SINGBOX_CONTROLLER_URL:-http://127.0.0.1:9090}"

controller_curl() {
	local secret
	secret="$(<"$SINGBOX_CLASH_API_SECRET_FILE")"
	printf 'header = "Authorization: Bearer %s"\n' "$secret" | curl --config - "$@"
}

validate_name() {
	local name="$1"
	[[ $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

load_subscriptions() {
	mapfile -t subscriptions < <(yq eval -r '.subscriptions // {} | keys | .[]' "$SINGBOX_SUBSCRIPTIONS_FILE")
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
		if [[ $selection =~ ^[0-9]+$ ]] && ((selection >= 1 && selection <= ${#subscriptions[@]})); then
			selected_subscription="${subscriptions[$((selection - 1))]}"
			return 0
		fi
		echo "无效选择"
	done
}

load_nodes() {
	mapfile -t nodes < <(yq eval -r '.nodes // {} | keys | .[]' "$SINGBOX_SUBSCRIPTIONS_FILE")
}

choose_node() {
	load_nodes
	if ((${#nodes[@]} == 0)); then
		echo "当前没有手动节点"
		return 1
	fi

	printf '\n'
	for index in "${!nodes[@]}"; do
		printf '%d) %s\n' "$((index + 1))" "${nodes[$index]}"
	done
	printf '0) 返回\n'

	while true; do
		read -r -p "请选择节点: " selection
		if [[ $selection == 0 ]]; then
			return 1
		fi
		if [[ $selection =~ ^[0-9]+$ ]] && ((selection >= 1 && selection <= ${#nodes[@]})); then
			selected_node="${nodes[$((selection - 1))]}"
			return 0
		fi
		echo "无效选择"
	done
}

wait_for_regeneration() {
	sleep 1
	for _ in {1..120}; do
		if systemctl is-failed --quiet sing-box-config-regenerate.service; then
			echo "配置生成失败，原有配置未被替换" >&2
			systemctl status sing-box-config-regenerate.service --no-pager -l >&2 || true
			return 1
		fi
		if ! systemctl is-active --quiet sing-box-config-regenerate.service; then
			if systemctl is-active --quiet sing-box.service; then
				echo "配置已生效，sing-box 正在运行"
			else
				echo "配置已保存；sing-box 当前未运行"
			fi
			return 0
		fi
		sleep 1
	done
	echo "等待配置生成超时" >&2
	return 1
}

replace_store() {
	local temporary_file="$1"
	chmod 0600 "$temporary_file"
	mv -f "$temporary_file" "$SINGBOX_SUBSCRIPTIONS_FILE"
	wait_for_regeneration
}

show_subscriptions() {
	load_subscriptions
	load_nodes
	if ((${#subscriptions[@]} == 0 && ${#nodes[@]} == 0)); then
		echo "当前没有订阅或手动节点"
		return
	fi

	provider_data="$(controller_curl --fail --silent --max-time 2 "$controller_url/proxies" || true)"
	printf '\n%-24s %s\n' "订阅" "节点数"
	printf '%-24s %s\n' "------------------------" "------"
	for name in "${subscriptions[@]}"; do
		if [[ -n $provider_data ]]; then
			node_count="$(jq -r --arg prefix "[$name] " '[.proxies | keys[] | select(startswith($prefix))] | length' <<<"$provider_data")"
		else
			node_count="-"
		fi
		printf '%-24s %s\n' "$name" "$node_count"
	done
	if ((${#nodes[@]} > 0)); then
		if [[ -n $provider_data ]]; then
			node_count="$(jq -r '[.proxies | keys[] | select(startswith("[手动] "))] | length' <<<"$provider_data")"
		else
			node_count="-"
		fi
		printf '%-24s %s\n' "手动节点" "$node_count"
	fi
}

add_subscription() {
	read -r -p "订阅名称: " name
	if ! validate_name "$name"; then
		echo "名称只能包含字母、数字、点、下划线和连字符" >&2
		return 1
	fi

	if [[ "$(SUBSCRIPTION_NAME="$name" yq eval '.subscriptions[strenv(SUBSCRIPTION_NAME)] != null' "$SINGBOX_SUBSCRIPTIONS_FILE")" == true ]]; then
		read -r -p "订阅已存在，是否替换？[y/N] " confirmation
		[[ $confirmation =~ ^[Yy]$ ]] || return 0
	fi

	read -r -s -p "订阅 URL: " url
	printf '\n'
	if [[ ! $url =~ ^https?:// ]]; then
		echo "URL 必须以 http:// 或 https:// 开头" >&2
		return 1
	fi

	temporary_file="$(mktemp "$SINGBOX_CONFIG_DIR/.subscriptions.yaml.XXXXXX")"
	cp "$SINGBOX_SUBSCRIPTIONS_FILE" "$temporary_file"
	SUBSCRIPTION_NAME="$name" SUBSCRIPTION_URL="$url" \
		yq eval -i '.subscriptions[strenv(SUBSCRIPTION_NAME)].url = strenv(SUBSCRIPTION_URL)' "$temporary_file"
	replace_store "$temporary_file"
}

remove_subscription() {
	choose_subscription || return 0
	read -r -p "确认删除 $selected_subscription？[y/N] " confirmation
	[[ $confirmation =~ ^[Yy]$ ]] || return 0

	temporary_file="$(mktemp "$SINGBOX_CONFIG_DIR/.subscriptions.yaml.XXXXXX")"
	cp "$SINGBOX_SUBSCRIPTIONS_FILE" "$temporary_file"
	SUBSCRIPTION_NAME="$selected_subscription" \
		yq eval -i 'del(.subscriptions[strenv(SUBSCRIPTION_NAME)])' "$temporary_file"
	replace_store "$temporary_file"
}

refresh_subscriptions() {
	if [[ ! -s $SINGBOX_SUBSCRIPTIONS_FILE ]]; then
		echo "当前没有订阅" >&2
		return 1
	fi
	touch "$SINGBOX_SUBSCRIPTIONS_FILE"
	wait_for_regeneration
}

add_node() {
	read -r -p "节点名称: " name
	if ! validate_name "$name"; then
		echo "名称只能包含字母、数字、点、下划线和连字符" >&2
		return 1
	fi

	if [[ "$(NODE_NAME="$name" yq eval '.nodes[strenv(NODE_NAME)] != null' "$SINGBOX_SUBSCRIPTIONS_FILE")" == true ]]; then
		read -r -p "节点已存在，是否替换？[y/N] " confirmation
		[[ $confirmation =~ ^[Yy]$ ]] || return 0
	fi

	read -r -s -p "分享链接: " link
	printf '\n'
	if [[ -z $link ]]; then
		echo "分享链接不能为空" >&2
		return 1
	fi
	if ! printf '%s\n' "$link" | "$SINGBOX_NODE_CHECK" --check-node; then
		echo "分享链接未通过校验，未保存" >&2
		return 1
	fi

	temporary_file="$(mktemp "$SINGBOX_CONFIG_DIR/.subscriptions.yaml.XXXXXX")"
	cp "$SINGBOX_SUBSCRIPTIONS_FILE" "$temporary_file"
	NODE_NAME="$name" NODE_LINK="$link" \
		yq eval -i '.nodes[strenv(NODE_NAME)].link = strenv(NODE_LINK)' "$temporary_file"
	replace_store "$temporary_file"
}

remove_node() {
	choose_node || return 0
	read -r -p "确认删除 $selected_node？[y/N] " confirmation
	[[ $confirmation =~ ^[Yy]$ ]] || return 0

	temporary_file="$(mktemp "$SINGBOX_CONFIG_DIR/.subscriptions.yaml.XXXXXX")"
	cp "$SINGBOX_SUBSCRIPTIONS_FILE" "$temporary_file"
	NODE_NAME="$selected_node" \
		yq eval -i 'del(.nodes[strenv(NODE_NAME)])' "$temporary_file"
	replace_store "$temporary_file"
}

if [[ ! -s $SINGBOX_SUBSCRIPTIONS_FILE ]]; then
	echo "订阅配置不存在，请先重新构建 NixOS" >&2
	exit 1
fi

while true; do
	cat <<'EOF'

sing-box 订阅管理
1) 查看订阅
2) 添加或替换订阅
3) 删除订阅
4) 刷新全部订阅
5) 添加或替换手动节点
6) 删除手动节点
0) 退出
EOF
	read -r -p "请选择操作: " action
	case "$action" in
	1) show_subscriptions ;;
	2) add_subscription ;;
	3) remove_subscription ;;
	4) refresh_subscriptions ;;
	5) add_node ;;
	6) remove_node ;;
	0) exit 0 ;;
	*) echo "无效选择" ;;
	esac
done
