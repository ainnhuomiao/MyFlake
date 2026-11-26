set shell := ["bash", "-euo", "pipefail", "-c"]

# 按当前主机名自动选择默认配置 (nixos / nixos-wsl), 其余环境回退到 nixos
default_host := `h=$(hostname 2>/dev/null || echo nixos); case "$h" in nixos|nixos-wsl) echo "$h" ;; *) echo nixos ;; esac`

# List available recipes
[default]
help:
    @just --list

# Update all flake inputs
update:
    nix flake update

# 更新单个 flake input
update-input name:
    nix flake lock --update-input {{name}}

# Check all flake outputs with nix-output-monitor
check:
    #!/usr/bin/env bash
    set -uo pipefail
    # 退出码以 nix 为准: nom 只要日志里有 error 级别消息就返回 1, 而 substituter 故障
    # (如某个 substituter 不可达)会被 nix 的 fallback 忽略、只记一条 error 日志, 不影响检查结果
    # 复用系统的 ncro 与 fallback 列表，避免与 build 的下载路径漂移。
    nix flake check --fallback --log-format internal-json -v 2>&1 | nom --json
    exit "${PIPESTATUS[0]}"

# Format the repository
format:
    nix fmt

# Build a NixOS configuration without activating it (nom output built in)
build host=default_host:
    nh os build . -H {{host}}

# 自动检测并替换本仓库 .nix 中失配的固定输出哈希 (默认目标: 当前主机系统闭包)
fix-hashes *args:
    python3 ./scripts/fix-hashes.py {{args}}

# Build an importable NixOS-WSL tarball (.wsl) for Windows
wsl-tarball out="nixos-wsl.wsl":
    sudo nix run .#nixosConfigurations.nixos-wsl.config.system.build.tarballBuilder -- "{{out}}"

# Show all flake outputs
show:
    nix flake show

# Enter the default development shell with nix-output-monitor
develop:
    nom develop

# List NixOS system generations
# nh os info shows generation list from the system profile
# (replace the old `nixos-rebuild list-generations`)
generations:
    nh os info

# Validate, format, and switch via nh (nom output built in)
rebuild-switch host=default_host: check format
    NIX_CONFIG="experimental-features = nix-command flakes" bash ./scripts/rebuild.sh {{host}}

# Fast path: build and switch without pre-check or formatting
rebuild-switch-fast host=default_host:
    NIX_CONFIG="experimental-features = nix-command flakes" bash ./scripts/rebuild.sh {{host}}

# Explicit full validation before switching
verify:
    just format
    just check

# Delete old generations and gcroots, keeping 3 generations and 7 days of history
# nh clean all extends nix-collect-garbage with gcroot cleanup
# (replace the old `nix-collect-garbage --delete-old`)
clean:
    nh clean all --keep 3 --keep-since 7d

# Partition and mount a target disk
disko:
    bash ./scripts/disko.sh

# Install NixOS on the mounted target
install:
    bash ./scripts/install.sh

# 提交已暂存的改动并直推当前分支(通常 main;未暂存的 WIP 不会被提交)
push msg *paths:
    bash ./scripts/push.sh "{{msg}}" {{paths}}

# 一键:git add -A(含未跟踪文件)后提交并直推 —— 会带上当时工作区的全部改动
push-all msg:
    bash ./scripts/push.sh --all "{{msg}}"

# 可选 PR 流程:基于 origin/main 建分支、提交并创建 PR(需 gh)
pr msg:
    bash ./scripts/push.sh --pr "{{msg}}"

# 同上并立即合并(留一条 PR 记录)
pr-merge msg:
    bash ./scripts/push.sh --pr --merge "{{msg}}"
