{
  pkgs,
  ...
}:
let
  v2rayN = pkgs.v2rayn;

  proxy = import ../../../lib/proxy-tools.nix { inherit pkgs; };
  # Shared proxy lifecycle; this wrapper only owns v2rayN and its child processes.
  wrapper = pkgs.writeShellApplication {
    name = "v2rayN";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
    ];
    text = proxy.shared + ''
      V2RAYN_BIN="${v2rayN}/bin/v2rayN"

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
        proxy_restore
      }

      trap restore_transparent_proxy EXIT
      trap 'exit 130' INT
      trap 'exit 143' TERM

      proxy_suspend
      proxy_watchdog &
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
