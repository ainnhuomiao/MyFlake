set shell := ["bash", "-euo", "pipefail", "-c"]

# 按当前主机名自动选择默认配置 (nixos / nixos-wsl), 其余环境回退到 nixos
default_host := `h=$(hostname 2>/dev/null || echo nixos); case "$h" in nixos|nixos-wsl) echo "$h" ;; *) echo nixos ;; esac`

# 列出可用命令
[default]
help:
    @just --list

# 更新全部或指定 flake inputs
update *inputs:
    nix flake update {{inputs}}

# 格式化仓库
fmt:
    nix fmt

# 使用 nix-output-monitor 检查全部 flake 输出
check:
    #!/usr/bin/env bash
    set -uo pipefail
    # 退出码以 nix 为准: nom 只要日志里有 error 级别消息就返回 1, 而 substituter 故障
    # (如某个 substituter 不可达)会被 nix 的 fallback 忽略、只记一条 error 日志, 不影响检查结果
    # 复用系统的 ncro 与 fallback 列表，避免与 build 的下载路径漂移。
    nix flake check --fallback --log-format internal-json -v 2>&1 | nom --json
    exit "${PIPESTATUS[0]}"

# 构建 NixOS 配置但不激活（内置 nom 输出）
build host=default_host:
    nh os build . -H {{host}}

# 格式化、检查并使用 nh 切换系统（内置 nom 输出）
switch host=default_host: fmt check
    NIX_CONFIG="experimental-features = nix-command flakes" bash ./scripts/rebuild.sh {{host}}

# 清理旧 generations 与 gcroots，保留最近 3 代与 7 天
clean:
    nh clean all --keep 3 --keep-since 7d

# 构建可直接导入 Windows 的 NixOS-WSL 镜像 (.wsl)
wsl-tarball out="nixos-wsl.wsl":
    sudo nix run .#nixosConfigurations.nixos-wsl.config.system.build.tarballBuilder -- "{{out}}"

# 对目标磁盘分区并挂载
disko:
    bash ./scripts/disko.sh

# 在已挂载的目标磁盘上安装 NixOS
install:
    bash ./scripts/install.sh
