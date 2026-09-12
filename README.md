<h1 align="center">
    <img src="assets/cirno.png" alt="MyFlake" width="360px" />
    <br>
    MyFlake
    <br>
    <a href="https://github.com/catppuccin/catppuccin">
        <img src="assets/palette-frappe.png" alt="Catppuccin Frappé" width="600px" />
    </a>
</h1>

<p align="center">
    个人 NixOS Flake 配置，当前面向 <code>x86_64-linux</code> 主机 <code>nixos</code>。仓库同时管理 NixOS、Home Manager、Sway 桌面、开发环境、AI CLI、dae + Mihomo 透明代理、自定义包与 overlays。
</p>

<div align="center">
    <a href="https://github.com/ainnhuomiao/MyFlake/actions/workflows/nix.yml">
        <img src="https://img.shields.io/github/actions/workflow/status/ainnhuomiao/MyFlake/nix.yml?style=for-the-badge&logo=githubactions&logoColor=white&label=CI&labelColor=303446" alt="CI" />
    </a>
    <a href="https://nixos.org">
        <img src="https://img.shields.io/badge/NixOS-26.05-8caaee?style=for-the-badge&logo=nixos&logoColor=eff1f5&labelColor=303446" alt="NixOS 26.05" />
    </a>
    <a href="https://github.com/xddxdd/nix-cachyos-kernel">
        <img src="https://img.shields.io/badge/Kernel-CachyOS%20x86__64__v3-ca9ee6?style=for-the-badge&logoColor=eff1f5&labelColor=303446" alt="CachyOS Kernel" />
    </a>
    <a href="https://flake.parts">
        <img src="https://img.shields.io/badge/Built%20with-flake--parts-ef9f76?style=for-the-badge&logoColor=eff1f5&labelColor=303446" alt="flake-parts" />
    </a>
    <a href="https://github.com/ainnhuomiao/MyFlake">
        <img src="https://img.shields.io/github/repo-size/ainnhuomiao/MyFlake?style=for-the-badge&logo=github&logoColor=babbf1&labelColor=303446&color=babbf1" alt="Repo Size" />
    </a>
</div>

> [!NOTE]
> 这是与个人硬件、用户名和本地状态绑定的配置，不是开箱即用的通用模板。复用前必须检查 `me.nix`、`hosts/nixos/`、磁盘布局以及涉及个人凭据的配置。

## 配置概览

| 项目         | 当前配置                                                                      |
| ------------ | ----------------------------------------------------------------------------- |
| Flake        | `flake-parts`                                                                 |
| Nixpkgs      | `nixos-unstable-small`                                                        |
| 平台         | `x86_64-linux`                                                                |
| 主机         | `nixos`                                                                       |
| 内核         | CachyOS latest `x86_64-v3`（pinned）                                          |
| 显卡         | 雷电显卡坞外接 RTX 3050（PRIME offload）                                      |
| 桌面         | swayfx（getty 自动登录直接进入）                                              |
| 用户环境     | Home Manager，作为 NixOS 模块集成                                             |
| Shell        | Fish + Starship                                                               |
| 音频         | PipeWire（ALSA、PulseAudio、JACK）                                            |
| 网络         | NetworkManager + dae eBPF + Mihomo SOCKS                                      |
| 二进制缓存   | GitHub Actions → Attic（VPS）+ Cachix + selector4nix 代理 + USTC 镜像（备用） |
| 引导         | GRUB EFI                                                                      |
| 文件系统     | Btrfs 子卷 + 独立 EFI 分区 + Swap                                             |
| 容器         | Docker + Distrobox + Flatpak                                                  |
| 系统状态版本 | NixOS `26.05`，Home Manager `25.11`                                           |

当前配置入口为：

```text
flake.nix
└── hosts/default.nix
    └── nixosConfigurations.nixos
        ├── hosts/nixos/
        ├── system/
        └── home/profiles/huomiao@nixos
```

## 主要功能

### 内核

当前主机使用 [`xddxdd/nix-cachyos-kernel`](https://github.com/xddxdd/nix-cachyos-kernel) `release` 分支提供的 CachyOS 内核。`hosts/default.nix` 注入 `overlays.pinned`，`hosts/nixos/default.nix` 选择 `linuxPackages-cachyos-latest-x86_64-v3`；这与上游 Hydra 的构建环境保持一致，可命中 `https://attic.xuyh0120.win/lantian` 二进制缓存，避免本机编译内核。

当前 `flake.lock` 对应的运行内核为 `7.2.4-cachyos`。更新 input 后版本会随 `release` 分支变化；不要让 `nix-cachyos-kernel.inputs.nixpkgs` 跟随本仓库的 `nixpkgs`，否则可能造成补丁版本不匹配或缓存未命中。切换内核配置后必须重启，运行中的版本可用 `uname -r` 检查。

### 桌面与日常应用

唯一 WM 为 **swayfx**（wlroots，支持毛玻璃模糊与窗口动画，`Mod` 为 `Super`）：状态栏、启动器、通知、锁屏、剪贴板与电源菜单全部由 **Noctalia** 提供（替代了此前的 Waybar/Rofi/Mako/swaylock 组合）。开机经 getty 自动登录直接进入 sway（fish 登录 shell 在 tty1 上自动 `exec sway`），无需显示管理器。

- Kitty、Firefox、Zen Browser、Google Chrome、Microsoft Edge
- 聊天：Telegram、QQ、Vesktop、WeChat、Discord、Feishu、腾讯会议、Element
- Flameshot、Grimshot、Satty、wf-recorder、wl-screenrec、Kooha、OBS Studio、Kdenlive
- MPV、SPlayer-Next、Go Musicfox、Bilibili 工具、Motrix Next、Blender、scrcpy
- Nemo、Yazi、Zathura、Obsidian、Emanote、imv/swayimg
- Thunderbird、DBeaver
- Fcitx5 + Rime + 中文扩展词库，左 `Ctrl` + 左 `Shift` 切换输入法
- PipeWire、Blueman、NetworkManager Applet、XDG Desktop Portal、Noctalia 通知
- btop 资源监视
- getty 自动登录直接进入 Sway（tty1），kmscon 接管其他虚拟终端显示中文
- 锁屏与待机：`swayidle` 挂起前触发 Noctalia 锁屏（桌面捕捉模糊，复刻 swaylock-blur）

### 雷电显卡坞（外接 RTX 3050）

主机通过 Thunderbolt 4 连接 LT-LINK 显卡坞，外接 RTX 3050 6GB（GA107）。桌面与显示始终由 iGPU 承担，游戏通过 PRIME offload 在 N 卡上渲染，无需额外显示器，支持热切换（坞电源开/关不用重启）。

日常使用（游戏入口自动检测，无需手动敲命令）：

- **Steam**：游戏属性 → 启动选项填一次 `nvidia-egpu %command%`
- **HMCL**（Minecraft）：设置 → Java 路径填 `/run/current-system/sw/bin/nvidia-egpu`，点启动即自动走 eGPU
- 手动：`nvidia-egpu steam` 亦可

`nvidia-egpu` 自动检测：GPU 健康 → 带 PRIME offload 环境运行；GPU 不可用（未通电/楔死）→ 自动清掉 nvidia 环境变量回退核显，游戏照常能玩（会有通知提示）。

```bash
# 玩完：退出游戏
nvidia-egpu-off              # 卸载驱动，提示“可安全关闭坞电源”后再关电
```

要点：

- `services.hardware.bolt` 负责雷电授权，坞已 `enroll --policy auto`，开电即自动授权
- 全局 EGL 锁定 Mesa + `WLR_DRM_DEVICES=/dev/dri/card0`（wlroots 只探测 iGPU），保证合成器不占用 nvidia 模块，驱动可在游戏结束后干净卸载，`nvidia-egpu-off` 卸载成功后再断电即安全
- `nvidia-egpu` wrapper 同时覆盖 GL/GLX（PRIME 变量）与 Vulkan（`MESA_VK_DEVICE_SELECT=10de:2584` 强制选卡；595.84 的 `VK_LAYER_NV_optimus` 已不再过滤设备），启动前自动检查/加载驱动；GPU 楔死时（`nvidia-smi -L` 仍 exit 0 但打印 “No devices found.”）不会放行坏 GPU
- 驱动 595.84 + **closed** 内核模块（`open = false`；open + GSP 固件在本机有已实证的 TLB/GSP RPC 崩溃）；坞通电时请勿合盖挂起

配置位置：`system/hardware/egpu.nix`（驱动、授权与 wrapper）、`home/wm/sway/default.nix`（`WLR_DRM_DEVICES`）。

### 开发环境

Home Manager 配置包含：

- 编辑器：Neovim、Helix、VSCode（Catppuccin Frappé 主题；Nix IDE、Nix Env Selector、Direnv、Claude Code 扩展）
- 版本控制：Git、GitHub CLI、Lazygit
- C/C++：GCC、Clang、GDB、CMake、Meson、Ninja、Bear
- Rust：`rust-overlay`
- Go、Haskell、Node.js、TypeScript、Bun
- Protobuf、gRPC、Direnv
- Nix：`nixd`、`nixfmt`、`treefmt-nix`、`nix-output-monitor`
- 外部二进制兼容：`nix-ld`

默认开发 Shell 提供 `git`、`jq`、`just`、`neovim`、`nom`。另有 `secret` Shell，提供 `age`、`sops` 和 `ssh-to-age`：

```bash
nix develop
nix develop .#secret
```

### AI CLI 与 MCP

`home/ai/` 当前安装：

- Antigravity CLI（`agy`，nixpkgs 已用其取代 gemini-cli）
- Claude Code
- Codex
- GitHub Copilot CLI
- OpenCode
- `cc-switch`
- Herdr
- Oh My Pi 与 Pi（来自 `llm-agents` 的 `omp`、`pi`）
- `omp-provider` 中文交互式配置工具
- `mcp-nixos`
- `flake-stats-mcp`

`omp-provider` 用于管理 Oh My Pi 的中转站、模型目录、模型策略、角色、备份与迁移：

```bash
omp-provider
omp-provider --doctor
```

Home Manager 激活时会将声明的 MCP 项合并到各工具配置中，不接管各工具的完整配置：

| 工具               | 配置位置                           |
| ------------------ | ---------------------------------- |
| Codex              | `~/.codex/config.toml`             |
| Claude Code        | `~/.claude.json`                   |
| Antigravity CLI    | `~/.gemini/config/mcp_config.json` |
| OpenCode           | `~/.config/opencode/opencode.json` |
| GitHub Copilot CLI | `~/.copilot/mcp-config.json`       |
| cc-switch          | `~/.cc-switch/cc-switch.db`        |

Context7 地址为 `https://mcp.context7.com/mcp`。如果 cc-switch 数据库存在，激活脚本还会同步其中的 Context7 记录和 Codex Live backup。

### 透明代理

当前采用 **dae + Mihomo** 双层架构：

```text
应用流量
  └─ dae：eBPF 透明代理、DNS 与路由
      ├─ 国内、私网、广播/多播 → DIRECT
      ├─ 广告与指定 Bilibili 遥测域名 → BLOCK
      ├─ auto.c3pool.org → 127.0.0.1:12347 → DAE-MINING
      └─ 其他流量 → 127.0.0.1:12346 → DAE-PROXY
```

dae 配置位于 `system/dae.dae`，主要行为：

- 自动选择出口网卡，透明代理端口为 `12345`，且不向防火墙开放该端口
- DNS 优先 IPv4；`geosite:cn` 使用阿里 DoQ `223.5.5.5:853`，其余请求回退到 Google TCP DNS `8.8.8.8:53`
- `proxy` 组固定使用 Mihomo SOCKS 上游 `127.0.0.1:12346`
- `mining` 组固定使用 Mihomo SOCKS 上游 `127.0.0.1:12347`
- `pname(mihomo) -> direct(must)` 防止 Mihomo 出站再次被 dae 捕获形成代理环路
- NetworkManager、私网、中国域名和中国 IP 直连；未命中的流量回退到 `proxy`

Mihomo 关闭 TUN，只负责订阅、节点健康检查和两个本地 SOCKS5 出口：

| Listener | Mihomo 组    | 用途                   |
| -------- | ------------ | ---------------------- |
| `12346`  | `DAE-PROXY`  | dae 的普通境外流量出口 |
| `12347`  | `DAE-MINING` | dae 的专用流量出口     |

订阅 URL 仅保存在 `/var/lib/mihomo-config/subscriptions.yaml`，不会写入 Nix store。订阅变化会触发配置重新生成、`mihomo -t` 校验和服务重启；生成失败时保留原配置。使用以下命令管理订阅：

```bash
mihomo-sub
```

Mihomo Zashboard 仅监听本机：

```text
http://127.0.0.1:9090/ui/
```

可在面板中分别选择 `DAE-PROXY` 和 `DAE-MINING` 的出口。当前没有启用 dae 自身的 WebUI；官方 `daed` 会同时接管 dae 后端和 eBPF 核心，不能与现有 `services.dae` 并行运行。

配置位置：

- `system/dae.nix`：dae 服务、Mihomo 启动依赖和反向路径检查
- `system/dae.dae`：DNS、双 SOCKS 上游、分组与透明路由规则
- `system/mihomo.nix`：订阅存储、配置生成器、两个 SOCKS listeners、Zashboard 和 `mihomo-sub`

### 二进制缓存代理

本机通过 [`selector4nix`](https://github.com/StarryReverie/selector4nix) 代理全部 Nix substituter 查询：

- 并行查询所有上游缓存，按延迟和优先级选择最快源；故障源自动跳过并按指数退避重试
- NAR 从最优源流式转发，本机只持久缓存 `.narinfo` 查询结果（`/var/cache/selector4nix`）
- 上游列表：`ainnhuomiao` Attic、`ainnhuomiao.cachix.org`、`nix-community.cachix.org`、`lantian` Attic、`cache.numtide.com`，以及 USTC 镜像（cache.nixos.org 的 CN 直连镜像，作通用二进制源）
- cache.nixos.org 不作为上游：dae 将其（非 geosite:cn）路由进 mihomo 节点，实测间歇性瘫痪/限速；nix 直连列表保留它作最后兜底
- `configureSubstituter = "prepend"`：代理 `http://127.0.0.1:5496/` 排在 substituters 首位，原始列表保留作 fallback；代理故障时 Nix 自动回退，不影响构建

配置位置：`system/nix/substituters.nix`。查看日志：

```bash
journalctl -u selector4nix -f
```

### 壁纸

壁纸直接存放在：

```text
assets/wallpapers/   # 静态壁纸（.png/.jpg/.jpeg/.webp）
assets/videos/       # 视频壁纸（.mp4/.webm/.mkv/.mov）
```

静态壁纸由 **Noctalia 自带壁纸管理器** 渲染（background layer），视频壁纸由 **官方 `noctalia/mpvpaper` 插件** 托管（插件按 output 拉起 mpvpaper，并让 Noctalia 在该 output 上收起自己的壁纸层）。浏览目录都用稳定软链，避免把每次重建都会变的 nix store 路径写进 Noctalia 状态：`~/Pictures/wallpapers` → `assets/wallpapers`，`~/Videos/wallpapers` → `assets/videos`。

- `Mod + Shift + w`：随机切换一次（静态）
- `Mod + Ctrl + w`：每 120 秒随机切换（静态）
- `Mod + Ctrl + Shift + w`：停止轮换并恢复默认壁纸
- `Mod + Ctrl + v`：打开视频壁纸选择器（选片/暂停/清除；分配会持久化，登录后自动恢复）
- `Mod + Ctrl + Shift + v`：清除视频壁纸，回到静态壁纸

状态栏的壁纸按钮打开静态壁纸选择器。休眠时用户服务会冻结视频壁纸，唤醒后解冻。

新增或替换仓库内壁纸后需要重建系统，使资源进入新的 Nix store 路径：

```bash
just rebuild-switch
```

### 主题（Catppuccin）

桌面配色固定为 Catppuccin **Mocha**，统一作用于 Kitty 终端、Sway 窗口边框与 Noctalia 外壳，不随壁纸变化、无运行时切换。锁屏亦为 Noctalia 内置 Catppuccin 主题。

配色定义在 `lib/appearance.nix`（`catppuccin` 四套 16 色 + `catppuccinVariant` 一行切换，改完重新 `just rebuild-switch` 生效）。

## 自定义包与 Flake 输出

`pkgs/` 中的本地包：

- `agy-hud`
- `bili_tui`
- `fcitx5-pinyin-moegirl`
- `fcitx5-pinyin-zhwiki`
- `flake-stats-mcp`
- `nordic`

`overlays/` 当前包含：

- `firefox`：固定 firefox-bin 154.0 与 zh-CN 语言包（nixpkgs 升级不再带动 Firefox 版本）
- `motrix-next`：跟随 nixpkgs 版本，只叠加 `autoPatchelfHook` 修复其 sidecar 在 NixOS 上的动态链接
- `mcp-nixos`：禁用一个会误判普通源码内容的上游测试
- `v2rayn`：修复 Linux TUN 门禁（rebuild 后节点延迟 -1 的根因）

Flake 对外提供 37 个包（`packages.x86_64-linux.*`）：

```text
agy-hud              antigravity-cli     bili_tui
bilibili             claude-code         discord
element-desktop      fcitx5-pinyin-moegirl fcitx5-pinyin-zhwiki
feishu               flake-stats-mcp     github-copilot-cli
google-chrome        herdr               hmcl
hyprpicker           mcp-nixos           microsoft-edge
motrix-next          noctalia            nordic
obsidian             omp                 pi
qq                   reasonix            selector4nix
steam                swayfx              thunderbird-bin
v2rayn               vscode              wechat
wemeet               wl-screenrec        wpsoffice-cn
zen-browser
```

来源：`noctalia`/`zen-browser` 来自各自 flake input，`herdr`/`hyprpicker`/`selector4nix` 来自对应 input，`reasonix`/`antigravity-cli`/`omp`/`pi` 来自 `llm-agents`，`agy-hud`/`bili_tui`/`fcitx5-pinyin-*`/`flake-stats-mcp`/`nordic` 为 `pkgs/` 本地包，其余为 nixpkgs 包。

CI **只构建「上游任何二进制缓存里都没有、必须从源码编译」的 9 个包**（`bili_tui`、`flake-stats-mcp`、`herdr`、`hyprpicker`、`mcp-nixos`、`motrix-next`、`selector4nix`、`swayfx`、`v2rayn`）并推送到自建 Attic 缓存。其余包都能直接替换（nixpkgs 自由软件走 cache.nixos.org，unfree 应用走厂商预编译包，`llm-agents` 走 cache.numtide.com，`noctalia` 走 noctalia.cachix.org），列进 CI 只会重复下载+上传，lock 更新后还要全部重来。

例如：

```bash
nix build .#omp
nix build .#pi
```

## 目录结构

```text
.
├── assets/wallpapers/       # 壁纸资源
├── flake/modules/           # packages、overlays、devShell、formatter 输出
├── home/                    # Home Manager 模块
│   ├── ai/                  # AI CLI、MCP 与 omp-provider
│   ├── dev/                 # 开发工具链
│   ├── editors/             # 编辑器
│   ├── profiles/            # 用户@主机配置组合
│   ├── programs/            # 桌面和命令行应用
│   ├── shell/               # Fish、Starship 与 Shell 工具
│   ├── terminals/           # 终端配置
│   ├── wall/                # 壁纸:Noctalia 静态 + mpvpaper 视频
│   └── wm/                  # swayfx WM 配置
├── hosts/                   # NixOS 主机定义
│   └── nixos/               # 当前物理机配置
├── lib/
│   ├── disko_layout/        # 普通与 LUKS 单盘布局
│   ├── scripts/             # 分区、安装、重建脚本
│   └── appearance.nix       # 公共配色与外观数据
├── overlays/                # nixpkgs overlays
├── pkgs/                    # 仓库自有包
├── system/                  # NixOS 系统模块
├── flake.nix
├── justfile
└── me.nix                   # 用户名、Git 信息和初始密码哈希
```

模块组织约定：

- `flake.nix` 声明 inputs，并组合 `flake/modules/` 与 `hosts/`
- `hosts/default.nix` 创建 NixOS 主机并绑定对应 Home Manager profile
- 各目录的 `default.nix` 主要负责聚合同目录模块
- 主机无关系统配置放在 `system/`，用户配置放在 `home/`

## 日常维护

仓库使用 `just` 管理常用命令（切换、清理与代际查看基于 [`nh`](https://github.com/nix-community/nh)，构建树可视化由 nh 内置的 nix-output-monitor 提供）：

| 命令                       | 作用                                                                   |
| -------------------------- | ---------------------------------------------------------------------- |
| `just`                     | 列出全部 recipes                                                       |
| `just update`              | 更新所有 Flake inputs                                                  |
| `just check`               | 执行 `nix flake check --fallback`                                      |
| `just format`              | 使用 Flake formatter 格式化仓库                                        |
| `just build [host]`        | 通过 `nh os build` 构建指定 NixOS 主机，不激活；默认 `nixos`           |
| `just show`                | 显示全部 Flake outputs                                                 |
| `just develop`             | 通过 `nom` 进入默认开发 Shell                                          |
| `just generations`         | 通过 `nh os info` 列出 NixOS 系统 generations                          |
| `just rebuild-switch`      | 先检查和格式化，再交互选择主机并通过 `nh os switch` 切换               |
| `just rebuild-switch-fast` | 快速路径：跳过检查和格式化，直接交互选择主机并通过 `nh os switch` 切换 |
| `just verify`              | 显式执行 `just check` 和 `just format`，用于严格验证                   |
| `just clean`               | 通过 `nh clean` 清理旧 generations 与 gcroots，保留最近 3 代和 7 天    |
| `just disko`               | 交互选择磁盘布局并分区、格式化、挂载                                   |
| `just install`             | 从 `/mnt/etc/nixos/flakes` 安装所选主机                                |

常用流程：

```bash
just update
just rebuild-switch
```

只验证、不切换：

```bash
just check
just build
```

> [!WARNING]
> `just clean` 会不可逆地删除旧 generations 与 gcroots（含 `result` 链接和 direnv gcroots），之后无法回滚到这些版本。

## CI 缓存与更新流程

推送到 `main` 后，GitHub Actions（`.github/workflows/nix.yml`）只会构建**上游无二进制缓存、必须从源码编译的 9 个包**并推送到自建 Attic 缓存（`ainnhuomiao.qianyuanqing.asia`）；其余包本就是预编译产物或已在上游缓存里，重建时直接替换即可，不必经 CI 搬运。因此**更新依赖后必须推送 `flake.lock`**，CI 才会为新路径重新构建那 9 个包。

### 日常更新（配置 / nixpkgs）

```bash
just update          # 升级所有 flake inputs（含 nixpkgs）
just rebuild-switch  # 检查、格式化、构建并切换
# 本地验证无误后推 main，CI 自动构建需源码编译的包进 Attic
```

`main` 允许直接推送（无需开 PR）：`just push "msg"` 提交**已暂存**的改动并直推（可写 `just push "msg" 路径…` 直接指定文件；未暂存的 WIP 不会被带上），`just push-all "msg"` 则是一键 `git add -A` 后提交直推。CI 在推送后运行 `nix.yml` 构建那 9 个源码包并推送到 Attic。`just pr` / `just pr-merge` 为可选 PR 流程（基于 `origin/main` 建分支、开 PR；后者立即合并）。

### 关于自动更新

不配置定时 `nix flake update` 工作流：`nixos-unstable` 的滚动升级可能夹带破坏性变更，无人值守时容易把半坏的 `flake.lock` 推上 `main`。依赖更新一律走上面的本地流程（`just update` → `just check`），确认通过后再推送。（原 `.github/workflows/flake-update.yml` 已移除。）

## 常用 Sway 快捷键

`Mod` 为 `Super`。

### 启动与系统

| 按键                   | 功能                      |
| ---------------------- | ------------------------- |
| `Mod + Return`         | 打开 Kitty                |
| `Mod + Shift + Return` | 打开浮动 Kitty            |
| `Mod + z`              | Noctalia 应用启动器       |
| `Mod + v`              | 剪贴板历史                |
| `Mod + Shift + p`      | 电源菜单                  |
| `Mod + Shift + b`      | Firefox                   |
| `Mod + Shift + t`      | Telegram                  |
| `Mod + Shift + q`      | QQ                        |
| `Mod + Shift + v`      | Vesktop                   |
| `Alt + Shift + s`      | SPlayer-Next              |
| `Alt + Shift + q`      | 切换到 QQ 工作区          |
| `Alt + Shift + t`      | 切换到 Telegram 工作区    |
| `Alt + Shift + w`      | 切换到 WeChat 工作区      |
| `Alt + Shift + b`      | 切换到 Firefox 工作区     |
| `Alt + Shift + v`      | 切换到 Vesktop 工作区     |
| `Alt + Shift + y`      | 切换到 Qutebrowser 工作区 |
| `Mod + Shift + x`      | 锁屏                      |
| `Mod + Shift + c`      | 重载 Sway                 |
| `Mod + Shift + e`      | 退出 Sway                 |
| `Mod + o`              | 显示或隐藏 Noctalia 顶栏  |

### 窗口与工作区

| 按键                             | 功能                     |
| -------------------------------- | ------------------------ |
| `Mod + h/j/k/l` 或方向键         | 移动焦点                 |
| `Mod + Shift + h/j/k/l` 或方向键 | 移动窗口                 |
| `Mod + q`                        | 关闭窗口                 |
| `Mod + f`                        | 全屏切换                 |
| `Mod + Shift + Space`            | 浮动/平铺切换            |
| `Mod + Space`                    | 在浮动区和平铺区切换焦点 |
| `Mod + 1..0`                     | 切换工作区 1..10         |
| `Mod + Shift + 1..0`             | 移动窗口到工作区         |
| `Mod + Ctrl + 1..0`              | 移动窗口并跟随到工作区   |
| `Mod + /`                        | 当前与上一个工作区切换   |
| `Mod + .` / `Mod + ,`            | 下一个/上一个工作区      |
| `Mod + -` / `Mod + =`            | 放入/取出 scratchpad     |
| `Mod + r`                        | 进入窗口大小调整模式     |
| `Mod + g` / `Mod + Shift + g`    | 关闭/恢复窗口间隙        |

### 截图与录制

| 按键/位置 | 功能                                         |
| --------- | -------------------------------------------- |
| `Print`   | Flameshot GUI                                |
| `Mod + [` | Grimshot 交互截图，复制并保存到 `~/Pictures` |
| `Mod + ]` | Grimshot 交互截图，仅复制                    |
| `Mod + a` | Grimshot 交互截图，复制并保存到 `~/Pictures` |

直接使用 `wf-recorder`：

```bash
wf-recorder -f recording.mkv
wf-recorder -g "$(slurp)" --audio -f recording.mkv
```

按 `Ctrl + C` 停止并保存。

## 全新安装

### 1. 进入安装环境

从 NixOS Minimal ISO 启动，联网后克隆仓库：

```bash
git clone <仓库地址> MyFlake
cd MyFlake
nix develop --extra-experimental-features 'nix-command flakes'
```

### 2. 修改个人与硬件配置

至少检查：

- `me.nix`
- `hosts/nixos/default.nix`
- `hosts/nixos/hardware-configuration.nix`
- `lib/disko_layout/single-device.nix`
- `lib/disko_layout/single-device-luks.nix`

不要复用当前机器的磁盘 UUID、设备路径或密码哈希。

### 3. 分区与挂载

```bash
just disko
```

脚本会：

1. 从 Flake 中发现 NixOS 主机
2. 选择普通单盘或 LUKS 单盘布局
3. 允许检查和编辑布局
4. 要求输入 `YES` 后才执行擦除、格式化和挂载
5. 生成目标主机的 `hardware-configuration.nix`
6. 将仓库复制到 `/mnt/etc/nixos/flakes`

> [!WARNING]
> 此操作会清空目标磁盘。执行前必须检查布局文件中的设备路径。

### 4. 安装

```bash
just install
```

安装脚本从 `/mnt/etc/nixos/flakes` 发现主机，交互设置用户密码，将密码哈希写入目标仓库的 `me.nix`，然后执行 `nixos-install`。

安装完成后重启：

```bash
reboot
```

## 注意事项

- `me.nix` 当前包含个人信息和密码哈希；公开仓库前应考虑迁移到 sops-nix 等秘密管理方案
- `sudo` 与 `doas` 均免密码提权（`sudo` 仅对 `huomiao`，`doas` 对 `wheel` 组），只适合受控的个人设备
- Home Manager 使用 `useGlobalPkgs = true` 和 `useUserPackages = true`；包变更应通过完整的 NixOS rebuild 应用
- `NIX_AUTO_RUN=1` 已启用，缺失命令可能由 nix-index/comma 临时运行；常用工具仍应显式声明
- Nix 每周自动执行 GC，并删除两天前的旧引用
- Flake 配置允许 unfree、broken 和 unsupported 包，并临时允许指定的不安全 Electron 版本；更新前应运行 `just check`
- CachyOS 内核更新并执行 `just rebuild-switch` 后仍需重启；若新内核无法启动，可从 GRUB 选择旧 NixOS generation 回退
- 当前硬件配置含本机 Btrfs、EFI 和 Swap UUID，不应复制到其他机器

## 参考

- [NixOS](https://nixos.org/)
- [Home Manager](https://github.com/nix-community/home-manager)
- [flake-parts](https://flake.parts/)
- [Disko](https://github.com/nix-community/disko)
- [Ruixi-rebirth/flakes](https://github.com/Ruixi-rebirth/flakes)
