{
  pkgs,
  ...
}:
let
  v2rayN = pkgs.v2rayn;

  # 包装 v2rayN：启动时停掉 dae(透明代理)+mihomo，退出(含崩溃/Ctrl+C)后自动恢复。
  # 依赖 system/mihomo.nix 与 system/dae.nix 里的 polkit 规则（免 sudo 管理这两个 unit）。
  # dae `Requires=mihomo.service`：停 mihomo 会连带停 dae，启动 dae 会连带拉起 mihomo；
  # 脚本仍显式按序 stop/start，避免依赖隐式传播。
  wrapper = pkgs.writeShellApplication {
    name = "v2rayN";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
    ];
    text = ''
      V2RAYN_BIN="${v2rayN}/bin/v2rayN"
      FLAG="''${XDG_RUNTIME_DIR:-/tmp}/v2rayN-managed-services"

      # TUN 模式能力自愈: v2rayN 替换/重下内核文件后 file capability 会丢,
      # 每次启动前补上 cap_net_admin,cap_net_raw(需 sudo 免密, 否则静默跳过,
      # TUN 不可用但普通代理模式不受影响)
      for core in \
        "$HOME/.local/share/v2rayN/bin/sing_box/sing-box" \
        "$HOME/.local/share/v2rayN/bin/xray/xray"
      do
        if [ -f "$core" ]; then
          sudo -n setcap cap_net_admin,cap_net_raw+ep "$core" 2>/dev/null || true
        fi
      done

      # wrapper 被外部信号终止时, 先杀掉后台 v2rayN 子进程再恢复服务,
      # 避免 v2rayN 变孤儿与 dae TUN 同时接管(正常退出时 kill 静默失败)
      CHILD_PID=""
      WATCHDOG_PID=""

      # 看门狗: nixos-rebuild switch 在 dae/mihomo 单元文件变更时, 会强制重启
      # 这两个单元——即使它们已被本脚本手动停掉(「重启」停着的单元=拉起来)。
      # dae 透明代理与 v2rayN TUN 同时在跑会形成路由回环(全部 dial timeout/
      # connection refused, 节点全 -1)。故 v2rayN 运行期间每 5s 巡检一次,
      # 发现服务被外力拉起就再次停掉; wrapper 退出时先杀看门狗再恢复服务。
      watchdog() {
        while [ -f "$FLAG" ] && [ -d "/proc/$PPID" ]; do
          if systemctl is-active --quiet dae.service 2>/dev/null && [ -f "$FLAG" ]; then
            systemctl stop dae.service 2>/dev/null || true
            echo "v2rayN: 看门狗发现 dae 被外力拉起(疑似 rebuild), 已再次停止"
          fi
          if systemctl is-active --quiet mihomo.service 2>/dev/null && [ -f "$FLAG" ]; then
            systemctl stop mihomo.service 2>/dev/null || true
            echo "v2rayN: 看门狗发现 mihomo 被外力拉起(疑似 rebuild), 已再次停止"
          fi
          sleep 5
        done
      }

      stop_transparent_proxy() {
        # 先 dae 后 mihomo，避免 Requires 传播顺序产生竞态。
        # 记录启动前状态：v2rayN 只是临时接管，退出时只恢复到"原本在跑"的服务，
        # 而不是无条件拉起(尊重用户 dae-toggle off 的手动关闭状态)。
        HAD_DAE=0
        HAD_MIHOMO=0
        if systemctl is-active --quiet dae.service 2>/dev/null; then
          HAD_DAE=1
          systemctl stop dae.service || true
        fi
        if systemctl is-active --quiet mihomo.service 2>/dev/null; then
          HAD_MIHOMO=1
          systemctl stop mihomo.service || true
        fi
        touch "$FLAG"
        echo "v2rayN: 已停止 dae + mihomo（透明代理旁路，由 v2rayN 接管）"
      }

      restore_transparent_proxy() {
        # 先杀看门狗再动服务, 避免竞态: 看门狗若在恢复后跑完最后一轮,
        # 会把刚恢复的 dae/mihomo 又停掉
        if [ -n "$WATCHDOG_PID" ]; then
          kill "$WATCHDOG_PID" 2>/dev/null || true
          wait "$WATCHDOG_PID" 2>/dev/null || true
        fi
        if [ -n "$CHILD_PID" ]; then
          # 避免孤儿 core 继续占端口/TUN(sudo 免密环境, -n 静默跳过)
          kill "$CHILD_PID" 2>/dev/null || true
          sudo -n pkill -TERM -f "$HOME/.local/share/v2rayN/bin/" 2>/dev/null || true
          sleep 1
          sudo -n pkill -KILL -f "$HOME/.local/share/v2rayN/bin/" 2>/dev/null || true
          wait "$CHILD_PID" 2>/dev/null || true
        fi
        if [ -f "$FLAG" ]; then
          rm -f "$FLAG"
          # 恢复到启动前状态：只在原本在跑的服务上 start(先 mihomo 后 dae)
          [ "''${HAD_MIHOMO:-0}" = "1" ] && systemctl start mihomo.service || true
          [ "''${HAD_DAE:-0}" = "1" ] && systemctl start dae.service || true
          sleep 0.3
          if [ "''${HAD_MIHOMO:-0}" = "1" ]; then
            systemctl is-active --quiet mihomo.service || \
              echo "v2rayN: 警告 mihomo.service 未运行, 请检查 systemctl status mihomo" >&2
          fi
          if [ "''${HAD_DAE:-0}" = "1" ]; then
            systemctl is-active --quiet dae.service || \
              echo "v2rayN: 警告 dae.service 未运行, 请检查 systemctl status dae" >&2
          fi
          if [ "''${HAD_DAE:-0}" = "1" ] || [ "''${HAD_MIHOMO:-0}" = "1" ]; then
            echo "v2rayN: 已退出, 恢复先前运行的 dae + mihomo（透明代理）"
          else
            echo "v2rayN: 已退出, dae + mihomo 原本未运行, 保持关闭"
          fi
        fi
      }

      trap restore_transparent_proxy EXIT

      stop_transparent_proxy
      watchdog &
      WATCHDOG_PID=$!
      "$V2RAYN_BIN" "$@" &
      CHILD_PID=$!
      wait "$CHILD_PID"
    '';
  };
in
{
  # 只装 wrapper：它与原始包都提供 `bin/v2rayN`，同时放 home.packages 会让 buildEnv
  # 撞名报错；wrapper 内嵌 ${v2rayN}/bin/v2rayN 绝对路径(被 Nix 扫描进闭包)，
  # 真实二进制随 wrapper 一起进入系统/home 闭包。
  # 同名 bin 保证终端输入 v2rayN 与下方 desktop 入口都走切换逻辑。
  home.packages = [
    wrapper
  ];

  # 覆盖 nixpkgs 自带的 v2rayn.desktop(Exec=v2rayN 走 PATH)：显式指向 wrapper 绝对路径
  home.file.".local/share/applications/v2rayn.desktop" = {
    text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=v2rayN
      GenericName=v2rayN
      Comment=Graphical client for Xray / sing-box; stops dae+mihomo on launch and restores them on exit
      Exec=${wrapper}/bin/v2rayN
      Icon=${v2rayN}/share/icons/hicolor/256x256/apps/v2rayn.png
      Categories=Network;
      Terminal=false
      StartupNotify=false
    '';
  };
}
