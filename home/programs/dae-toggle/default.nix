{
  pkgs,
  ...
}:
let
  proxy = import ../../../lib/proxy-tools.nix { inherit pkgs; };
  daeToggle = pkgs.writeShellApplication {
    name = "dae-toggle";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
      libnotify
    ];
    text = proxy.shared + ''

      notify() {
        if command -v notify-send >/dev/null 2>&1; then
          notify-send --app-name=dae-toggle "$@" 2>/dev/null || true
        fi
      }

      print_status() { proxy_status; }

      enable_proxy() {
        printf 'dae-toggle: 启动 mihomo + dae…\n'
        if ! proxy_start; then
          notify -i dialog-error "dae+mihomo 启动失败" "请检查服务状态或退出 v2rayN"
          return 1
        fi
        printf 'dae-toggle: 已开启（透明代理接管）\n'
        notify -i dialog-information "dae+mihomo 已开启" "透明代理已接管"
        print_status
      }

      disable_proxy() {
        printf 'dae-toggle: 停止 dae + mihomo…\n'
        proxy_stop
        printf 'dae-toggle: 已关闭（当前为直连）\n'
        notify -i dialog-information "dae+mihomo 已关闭" "当前为直连网络"
        print_status
      }

      toggle_proxy() {
        if [[ "$(proxy_unit_state dae.service)" == "active" ]]; then
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
