#!/usr/bin/env bash

set -euo pipefail

# Usage: rebuild.sh [host]   (default: $NH_HOST, else matching hostname, else "nixos")
current_host="$(hostname 2>/dev/null || echo nixos)"
case "$current_host" in
nixos | nixos-wsl) default_host="$current_host" ;;
*) default_host="nixos" ;;
esac
host="${1:-${NH_HOST:-$default_host}}"
auto_fix="${AUTO_FIX_HASHES:-1}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
log_file="$(mktemp -t rebuild-switch.XXXXXX.log)"
trap 'rm -f "$log_file"' EXIT

run_switch() {
	local log="$1"
	if command -v script >/dev/null 2>&1; then
		local cmd
		printf -v cmd 'nh os switch . -H %q' "$host"
		script -qefc "$cmd" "$log"
	else
		nh os switch . -H "$host" 2>&1 | tee "$log"
	fi
}

# nh self-elevates with sudo when needed; nom output is built in
echo "🚀 Rebuilding $host..."
if run_switch "$log_file"; then
	exit 0
else
	rc=$?
fi

if [[ "$auto_fix" == "1" && "$rc" -ne 130 && "$rc" -ne 143 ]] &&
	grep -q "hash mismatch in fixed-output derivation" "$log_file"; then
	echo "🔧 检测到固定输出哈希失配，尝试自动更新本仓库 .nix 哈希..."
	if python3 "$repo_root/scripts/fix-hashes.py" --from-log "$log_file" ".#nixosConfigurations.${host}.config.system.build.toplevel"; then
		echo "🚀 本地哈希已更新，重新执行 nh os switch . -H $host..."
		rm -f "$log_file"
		exec nh os switch . -H "$host"
	fi
fi

exit "$rc"
