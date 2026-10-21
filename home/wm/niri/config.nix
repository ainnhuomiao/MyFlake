{
  lib,
  pkgs,
  appearance,
}:
let
  h = appearance.toHex;
  cp = appearance.catppuccin;
  workspaces = map toString (lib.range 1 5);
  # 直接使用锁定 DMS 版本随包提供的 niri 预设，仅选择本机已安装的 Kitty 终端。
  # 在构建阶段替换模板，避免读取 derivation 内容导致求值阶段构建（IFD）。
  defaultBinds = pkgs.runCommand "dms-niri-default-binds.kdl" { } ''
    substitute ${pkgs.dms-shell.src}/core/internal/config/embedded/niri-binds.kdl "$out" \
      --replace-fail '{{TERMINAL_COMMAND}}' 'kitty'
  '';
in
''
  // 由 Home Manager 生成；请修改 home/wm/niri/config.nix，不运行 dms setup 覆盖此文件。
  input {
      keyboard {
          xkb {
              layout "us"
          }
      }
      touchpad {
          tap
          natural-scroll
          middle-emulation
      }
      mod-key "Super"
  }

  output "eDP-1" { scale 1.25; }

  layout {
      gaps 5
      center-focused-column "never"
      preset-column-widths {
          proportion 0.33333
          proportion 0.5
          proportion 0.66667
      }
      default-column-width { proportion 0.5; }
      focus-ring {
          width 2
          active-color "${h cp.mauve}"
          inactive-color "${h cp.surface1}"
      }
      border { off; }
      shadow {
          on
          color "#00000050"
      }
      background-color "${h cp.base}"
  }

  prefer-no-csd
  screenshot-path "~/Pictures/Screenshots/%Y-%m-%dT%H_%M_%S.png"

  // niri 原生托管 XWayland，首次连接 X11 应用时启动 satellite。
  xwayland-satellite { path "xwayland-satellite"; }

  // 核显渲染；忽略外接 NVIDIA 的 render 节点，延续 eGPU 卸载需求。
  // eGPU 热插拔后仍需实测 niri 是否打开了新节点，再执行 nvidia-egpu-off。
  debug {
      render-drm-device "/dev/dri/by-path/pci-0000:00:02.0-render"
      ignore-drm-device "/dev/dri/renderD129"
  }

  // DMS 由 systemd 单独启动；这里不重复 spawn。
  spawn-at-startup "fcitx5" "-d"
  spawn-at-startup "sh" "-c" "xrdb -merge \"$HOME/.Xresources\""

  ${lib.concatMapStringsSep "\n" (n: ''workspace "${n}"'') workspaces}

  window-rule {
      geometry-corner-radius 10
      clip-to-geometry true
  }
  window-rule {
      match app-id="^(termfloat|mpv|nemo|ncmpcpp)$"
      open-floating true
      default-column-width { fixed 960; }
      default-window-height { fixed 540; }
  }
  window-rule {
      match app-id="^(org\\.gnome\\.|org\\.gtk\\.)" title="^(Open|Save|打开|保存)"
      open-floating true
  }

  // DMS 官方默认按键；随 flake.lock 中的 DMS 版本同步。
  include "${defaultBinds}"
''
