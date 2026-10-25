{
  config,
  lib,
  pkgs,
  appearance,
  ...
}:
let
  h = appearance.toHex;
  cp = appearance.catppuccin;
  noctalia = lib.getExe config.programs.noctalia.package;
  workspaces = map toString (lib.range 1 5);
in
{
  wayland.windowManager.niri.extraConfig = ''
    input {
        keyboard {
            xkb {
                layout "us"
                options "caps:escape"
            }
        }
        touchpad {
            tap
            natural-scroll
            middle-emulation
        }
        // 不启用 focus-follows-mouse,保持点击/键盘聚焦。
    }

    output "eDP-1" {
        scale 1.25
    }

    // 固定核显渲染,并排除显卡坞。udev 别名按设备身份生成,不依赖 card 编号/BDF。
    debug {
        render-drm-device "/dev/dri/by-path/pci-0000:00:02.0-render"
        ignore-drm-device "/dev/dri/nvidia-egpu-render"
    }

    prefer-no-csd
    cursor {
        xcursor-theme "${config.home.pointerCursor.name}"
        xcursor-size ${toString config.home.pointerCursor.size}
    }
    layout {
        gaps 5
        // 透出 backdrop 中的壁纸,避免空工作区显示为灰色。
        background-color "transparent"
        // 取消最大化时恢复半屏宽;新窗口的初始最大化状态由下方规则设置。
        default-column-width { proportion 0.5; }
        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }
        focus-ring { off; }
        border { off; }
        shadow {
            on
            color "${h cp.crust}80"
        }
        tab-indicator {
            active-color "${h cp.mauve}"
            inactive-color "${h cp.surface2}"
            urgent-color "${h cp.red}"
        }
    }
    // 保留终端当前透明度,迁移时不额外开启背景模糊。
    blur { off; }
    hotkey-overlay { skip-at-startup; }
    screenshot-path "~/Pictures/%Y-%m-%dT%H_%M_%S.png"

    ${lib.concatMapStringsSep "\n" (name: ''workspace "${name}"'') workspaces}

    // 仅会话启动时执行,配置热重载不会重复启动。
    // xrdb 连接 niri 提供的 DISPLAY,satellite 由 niri 按需拉起。
    spawn-sh-at-startup "${pkgs.xrdb}/bin/xrdb -merge \"$HOME/.Xresources\""
    spawn-at-startup "fcitx5" "-d"
    spawn-at-startup "${noctalia}" "--daemon"

    // 总览背景使用 Noctalia 的模糊壁纸层;视频壁纸则沿用 mpvpaper 层。
    layer-rule {
        match namespace="^(noctalia-backdrop|mpvpaper)$"
        place-within-backdrop true
    }

    window-rule {
        draw-border-with-background false
        open-maximized true
    }
    window-rule {
        match app-id="(?i)^(termfloat|mpv|nemo|ncmpcpp)$"
        open-floating true
        open-maximized false
        default-column-width { fixed 960; }
        default-window-height { fixed 540; }
    }
    // 普通主窗口保持平铺;独立会议窗口浮动。
    window-rule {
        match app-id="(?i)^Main_Meeting$"
        open-floating true
        open-maximized false
    }
    // 共享控制条不抢初始焦点,仅在所属工作区浮动,不模拟全工作区粘滞。
    window-rule {
        match app-id="(?i)^ShareScreenFloatingPanelWindowBase$"
        open-floating true
        open-maximized false
        open-focused false
        border { off; }
        focus-ring { off; }
    }
    window-rule {
        match app-id="(?i)^(flameshot|org\\.flameshot\\.Flameshot)$"
        open-floating true
        open-maximized false
        open-fullscreen true
        border { off; }
        focus-ring { off; }
        shadow { off; }
    }

    // 单独保留 Alt-Tab;Super-Tab 用于概览,不与 recent-windows 默认键冲突。
    recent-windows {
        binds {
            Alt+Tab { next-window; }
            Alt+Shift+Tab { previous-window; }
        }
        highlight {
            active-color "${h cp.mauve}"
            urgent-color "${h cp.red}"
        }
    }

    binds {
        Mod+O { spawn "${noctalia}" "msg" "bar-toggle"; }
        Mod+Z { spawn "${noctalia}" "msg" "panel-toggle" "launcher"; }
        Mod+V { spawn "${noctalia}" "msg" "panel-toggle" "clipboard"; }
        Mod+Shift+P { spawn "${noctalia}" "msg" "panel-toggle" "session"; }
        Mod+Shift+X allow-inhibiting=false { spawn "${noctalia}" "msg" "session" "lock"; }

        Print { spawn "flameshot" "gui"; }
        Mod+BracketLeft { spawn "grimshot-savecopy"; }
        // 26.04 的交互 screenshot 没有 write-to-disk 参数,仅复制走 Grimshot area。
        Mod+BracketRight { spawn "grimshot" "--notify" "copy" "area"; }
        Mod+A { spawn "grimshot-savecopy"; }

        Mod+Return { spawn "kitty"; }
        Mod+Shift+Return { spawn "kitty" "--class" "termfloat"; }
        Mod+Shift+B { spawn "firefox"; }
        Mod+Shift+Y { spawn "qutebrowser"; }
        Mod+Shift+T { spawn "Telegram"; }
        Mod+Shift+Q { spawn "linuxqq-wayland-fix"; }
        Alt+Shift+S { spawn "SPlayer-Next"; }
        Mod+Shift+V { spawn "vesktop"; }

        XF86AudioPlay { spawn "mpc" "-q" "toggle"; }
        XF86AudioNext { spawn "mpc" "-q" "next"; }
        XF86AudioPrev { spawn "mpc" "-q" "prev"; }
        XF86AudioRaiseVolume allow-when-locked=true { spawn "${pkgs.pamixer}/bin/pamixer" "-i" "5"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "${pkgs.pamixer}/bin/pamixer" "-d" "5"; }
        XF86AudioMute allow-when-locked=true { spawn "${pkgs.pamixer}/bin/pamixer" "-t"; }
        XF86AudioMicMute allow-when-locked=true { spawn "${pkgs.pamixer}/bin/pamixer" "--default-source" "-t"; }
        XF86MonBrightnessUp allow-when-locked=true { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%+"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%-"; }

        Mod+Q { close-window; }
        Alt+F4 { close-window; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+Space { toggle-window-floating; }
        Mod+Shift+Space { switch-focus-between-floating-and-tiling; }
        Mod+R { switch-preset-column-width; }
        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }
        Mod+Shift+Minus { set-window-height "-10%"; }
        Mod+Shift+Equal { set-window-height "+10%"; }
        Mod+Ctrl+BracketLeft { consume-or-expel-window-left; }
        Mod+Ctrl+BracketRight { consume-or-expel-window-right; }
        Mod+W { toggle-column-tabbed-display; }
        Mod+Tab { toggle-overview; }
        Mod+Shift+E { quit; }
        Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
        Mod+Shift+Slash { show-hotkey-overlay; }

        ${lib.concatMapStringsSep "\n"
          (
            direction:
            let
              key = direction.key;
              axis = direction.axis;
            in
            ''
              Mod+${key} { focus-${axis}-${direction.name}; }
              Mod+Shift+${key} { move-${axis}-${direction.name}; }
            ''
          )
          [
            {
              key = "Left";
              axis = "column";
              name = "left";
            }
            {
              key = "H";
              axis = "column";
              name = "left";
            }
            {
              key = "Right";
              axis = "column";
              name = "right";
            }
            {
              key = "L";
              axis = "column";
              name = "right";
            }
            {
              key = "Up";
              axis = "window";
              name = "up";
            }
            {
              key = "K";
              axis = "window";
              name = "up";
            }
            {
              key = "Down";
              axis = "window";
              name = "down";
            }
            {
              key = "J";
              axis = "window";
              name = "down";
            }
          ]
        }

        ${lib.concatMapStringsSep "\n"
          (direction: ''
            Mod+Ctrl+${direction.key} { focus-monitor-${direction.name}; }
            Mod+Ctrl+Shift+${direction.key} { move-column-to-monitor-${direction.name}; }
          '')
          [
            {
              key = "Left";
              name = "left";
            }
            {
              key = "Right";
              name = "right";
            }
            {
              key = "Up";
              name = "up";
            }
            {
              key = "Down";
              name = "down";
            }
          ]
        }

        // 引用字符串名称,避免动态工作区改变编号后切错位置。
        ${lib.concatMapStringsSep "\n" (name: ''
          Mod+${name} { focus-workspace "${name}"; }
          Mod+Shift+${name} { move-window-to-workspace "${name}" focus=false; }
          Mod+Ctrl+${name} { move-window-to-workspace "${name}" focus=true; }
        '') workspaces}
        Mod+Slash { focus-workspace-previous; }
        Mod+Comma { focus-workspace-up; }
        Mod+Period { focus-workspace-down; }
    }
  '';
}
