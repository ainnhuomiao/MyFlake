#!/usr/bin/env bash
# Complete system update: flake update → check → format → build+switch TWICE
# (registry snapshot needs two rebuilds to consume the new nixpkgs) → verify.
# Follows the verified MyFlake update workflow (2026-08-20).
# Manual extras from the full workflow:
#   - 清理旧代际: just clean
#
# Stops on first failure. After any failure, restore with:
#   git checkout -- flake.lock   (running system is decoupled from the lock)

set -euo pipefail

export NIX_CONFIG="experimental-features = nix-command flakes"
cd "$(dirname "$0")/../.."

echo "=== [1/6] 更新所有 flake inputs (nix flake update) ==="
nix flake update --log-format internal-json -v 2>&1 | nom --json

echo "=== [2/6] 静态检查 (nix flake check) ==="
if ! nix flake check --fallback --log-format internal-json -v 2>&1 | nom --json; then
  echo "❌ nix flake check 失败"
  if ! curl -s -o /dev/null -w "%{http_code}" --max-time 15 https://cache.nixos.org/nix-cache-info | grep -q 200; then
    echo "   cache.nixos.org 不可达（环境问题），跳过 check 继续"
  else
    exit 1
  fi
fi

echo "=== [3/6] 格式化 (nix fmt) ==="
nix fmt

echo "=== [4/6] 构建安全网 (nh os build) ==="
nh os build . -H nixos

echo "=== [5/6] 两次切换 (registry 快照需两次 rebuild 才消费新 nixpkgs) ==="
NIX_CONFIG="$NIX_CONFIG" bash ./lib/scripts/rebuild.sh
NIX_CONFIG="$NIX_CONFIG" bash ./lib/scripts/rebuild.sh

echo "=== [6/6] 完成。验证： ==="
echo "  readlink /run/current-system"
echo "  nix eval --raw .#nixosConfigurations.nixos.config.system.nixos.version"
echo "  jq -r '.flakes[0].to | .rev' /etc/nix/registry.json"
echo "  清理旧代际: just clean"
echo "  提交: git add flake.lock && git commit && git push"
