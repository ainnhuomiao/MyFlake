{ pkgs, ... }:
let
  singBoxToggle = pkgs.writeShellApplication {
    name = "sing-box-toggle";
    runtimeInputs = with pkgs; [
      libnotify
      systemd
    ];
    text = ''
      notify() {
        if command -v notify-send >/dev/null 2>&1; then
          notify-send --app-name=sing-box-toggle "$@" 2>/dev/null || true
        fi
      }

      print_status() {
        systemctl status sing-box.service --no-pager -n 0 || true
      }

      enable_proxy() {
        if ! systemctl start sing-box.service; then
          notify -i dialog-error "sing-box 启动失败" "请检查 systemctl status sing-box"
          return 1
        fi
        printf 'sing-box-toggle: 已开启透明代理\n'
        notify -i dialog-information "sing-box 已开启" "透明代理已接管"
      }

      disable_proxy() {
        systemctl stop sing-box.service
        printf 'sing-box-toggle: 已关闭，当前为直连网络\n'
        notify -i dialog-information "sing-box 已关闭" "当前为直连网络"
      }

      case "''${1:-toggle}" in
      on | start | enable) enable_proxy ;;
      off | stop | disable) disable_proxy ;;
      status) print_status ;;
      toggle)
        if systemctl is-active --quiet sing-box.service; then
          disable_proxy
        else
          enable_proxy
        fi
        ;;
      *)
        printf 'sing-box-toggle 用法: sing-box-toggle [on|off|status|toggle]\n' >&2
        exit 2
        ;;
      esac
    '';
  };
in
{
  home.packages = [ singBoxToggle ];
}
