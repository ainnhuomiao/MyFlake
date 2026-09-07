{
  pkgs,
  ...
}:
let
  daeToggle = pkgs.writeShellApplication {
    name = "dae-toggle";
    runtimeInputs = with pkgs; [
      systemd
      libnotify
    ];
    text = ''
      # 一键开启/关闭 dae + mihomo 透明代理。
      # 依赖 system/dae.nix 与 system/mihomo.nix 的 polkit 免密规则，普通用户无需 sudo。
      # dae Requires=mihomo：脚本显式按序 start/stop，避免 systemd 隐式传播的竞态。
      #
      # 用法: dae-toggle [on|off|status|toggle]   (默认 toggle)
      set -u

      UNITS=(dae.service mihomo.service)

      notify() {
        if command -v notify-send >/dev/null 2>&1; then
          notify-send --app-name=dae-toggle "$@" 2>/dev/null || true
        fi
      }

      unit_state() {
        local st
        st="$(systemctl is-active "$1" 2>/dev/null)" || true
        printf '%s' "''${st:-inactive}"
      }

      print_status() {
        local u
        for u in "''${UNITS[@]}"; do
          printf '%-14s %s\n' "$u" "$(unit_state "$u")"
        done
      }

      enable_proxy() {
        printf 'dae-toggle: 启动 mihomo + dae…\n'
        systemctl start mihomo.service || {
          printf 'dae-toggle: mihomo.service 启动失败\n' >&2
          notify -i dialog-error "dae+mihomo 启动失败" "mihomo.service 启动失败"
          return 1
        }
        systemctl start dae.service || {
          printf 'dae-toggle: dae.service 启动失败\n' >&2
          notify -i dialog-error "dae+mihomo 启动失败" "dae.service 启动失败"
          return 1
        }
        printf 'dae-toggle: 已开启（透明代理接管）\n'
        notify -i dialog-information "dae+mihomo 已开启" "透明代理已接管"
        print_status
      }

      disable_proxy() {
        printf 'dae-toggle: 停止 dae + mihomo…\n'
        systemctl stop dae.service 2>/dev/null || true
        systemctl stop mihomo.service 2>/dev/null || true
        printf 'dae-toggle: 已关闭（当前为直连）\n'
        notify -i dialog-information "dae+mihomo 已关闭" "当前为直连网络"
        print_status
      }

      toggle_proxy() {
        if [[ "$(unit_state dae.service)" == "active" ]]; then
          disable_proxy
        else
          enable_proxy
        fi
      }

      case "''${1:-toggle}" in
        on|start|enable) enable_proxy ;;
        off|stop|disable) disable_proxy ;;
        status) print_status ;;
        toggle) toggle_proxy ;;
        *)
          printf 'dae-toggle 用法: dae-toggle [on|off|status|toggle]\n' >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  home.packages = [ daeToggle ];
}
