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
    // 允许 Noctalia 等 layer surface 按需请求背景模糊;普通窗口不额外开启。
    blur {
        passes 3
        offset 2.0
        noise 0.02
        saturation 1.1
    }
    hotkey-overlay {
        skip-at-startup
        hide-not-bound
    }
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
        // 为原生快捷键浮层提供中文说明;媒体/跨屏等完整键位见 README。
        Mod+O hotkey-overlay-title="显示／隐藏状态栏" { spawn "${noctalia}" "msg" "bar-toggle"; }
        Mod+Z hotkey-overlay-title="打开应用启动器" { spawn "${noctalia}" "msg" "panel-toggle" "launcher"; }
        Mod+V hotkey-overlay-title="打开剪贴板历史" { spawn "${noctalia}" "msg" "panel-toggle" "clipboard"; }
        Mod+Shift+P hotkey-overlay-title="打开电源与会话菜单" { spawn "${noctalia}" "msg" "panel-toggle" "session"; }
        Mod+Shift+X allow-inhibiting=false hotkey-overlay-title="锁定屏幕" { spawn "${noctalia}" "msg" "session" "lock"; }

        Print hotkey-overlay-title="截图并标注（Flameshot）" { spawn "flameshot" "gui"; }
        Mod+BracketLeft hotkey-overlay-title="交互截图：保存并复制（也可按 Super+A）" { spawn "grimshot-savecopy"; }
        // 26.04 的交互 screenshot 没有 write-to-disk 参数,仅复制走 Grimshot area。
        Mod+BracketRight hotkey-overlay-title="交互截图：仅复制" { spawn "grimshot" "--notify" "copy" "area"; }
        Mod+A { spawn "grimshot-savecopy"; }

        Mod+Return hotkey-overlay-title="打开终端（Kitty）" { spawn "kitty"; }
        Mod+Shift+Return hotkey-overlay-title="打开浮动终端（Kitty）" { spawn "kitty" "--class" "termfloat"; }
        Mod+Shift+B hotkey-overlay-title="打开 Firefox 浏览器" { spawn "firefox"; }
        Mod+Shift+Y hotkey-overlay-title="打开 Qutebrowser 浏览器" { spawn "qutebrowser"; }
        Mod+Shift+T hotkey-overlay-title="打开 Telegram" { spawn "Telegram"; }
        Mod+Shift+Q hotkey-overlay-title="打开 QQ" { spawn "linuxqq-wayland-fix"; }
        Alt+Shift+S hotkey-overlay-title="打开音乐播放器（SPlayer）" { spawn "SPlayer-Next"; }
        Mod+Shift+V hotkey-overlay-title="打开 Vesktop" { spawn "vesktop"; }

        XF86AudioPlay { spawn "mpc" "-q" "toggle"; }
        XF86AudioNext { spawn "mpc" "-q" "next"; }
        XF86AudioPrev { spawn "mpc" "-q" "prev"; }
        XF86AudioRaiseVolume allow-when-locked=true { spawn "${pkgs.pamixer}/bin/pamixer" "-i" "5"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "${pkgs.pamixer}/bin/pamixer" "-d" "5"; }
        XF86AudioMute allow-when-locked=true { spawn "${pkgs.pamixer}/bin/pamixer" "-t"; }
        XF86AudioMicMute allow-when-locked=true { spawn "${pkgs.pamixer}/bin/pamixer" "--default-source" "-t"; }
        XF86MonBrightnessUp allow-when-locked=true { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%+"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%-"; }

        Mod+Q hotkey-overlay-title="关闭当前窗口（也可按 Alt+F4）" { close-window; }
        Alt+F4 { close-window; }
        Mod+F hotkey-overlay-title="满宽／半屏切换" { maximize-column; }
        Mod+Shift+F hotkey-overlay-title="切换真全屏" { fullscreen-window; }
        Mod+Space hotkey-overlay-title="切换浮动／平铺" { toggle-window-floating; }
        Mod+Shift+Space hotkey-overlay-title="在浮动与平铺窗口间切换焦点" { switch-focus-between-floating-and-tiling; }
        Mod+R hotkey-overlay-title="切换列宽：1/3、1/2、2/3（Super+-/= 微调）" { switch-preset-column-width; }
        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }
        Mod+Shift+Minus { set-window-height "-10%"; }
        Mod+Shift+Equal { set-window-height "+10%"; }
        Mod+Ctrl+BracketLeft hotkey-overlay-title="向左并入或拆出当前窗口" { consume-or-expel-window-left; }
        Mod+Ctrl+BracketRight hotkey-overlay-title="向右并入或拆出当前窗口" { consume-or-expel-window-right; }
        Mod+W hotkey-overlay-title="切换列内标签布局" { toggle-column-tabbed-display; }
        Mod+Tab hotkey-overlay-title="打开／关闭工作区概览" { toggle-overview; }
        Mod+Shift+E hotkey-overlay-title="退出 niri（先确认）" { quit; }
        Mod+Escape allow-inhibiting=false hotkey-overlay-title="解除／恢复应用的快捷键独占" { toggle-keyboard-shortcuts-inhibit; }
        Mod+Shift+Slash hotkey-overlay-title="显示快捷键提示（Esc 关闭）" { show-hotkey-overlay; }

        ${lib.concatMapStringsSep "\n"
          (
            direction:
            let
              key = direction.key;
              axis = direction.axis;
              directionName =
                {
                  left = "左";
                  right = "右";
                  up = "上";
                  down = "下";
                }
                .${direction.name};
              target = if axis == "column" then "列" else "窗口";
            in
            ''
              Mod+${key} hotkey-overlay-title="向${directionName}切换${target}（方向键或 HJKL）" { focus-${axis}-${direction.name}; }
              Mod+Shift+${key} hotkey-overlay-title="向${directionName}移动${target}（方向键或 HJKL）" { move-${axis}-${direction.name}; }
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
        // 数字工作区只展示一组范例,避免重复列出 15 行挤出屏幕。
        ${lib.concatMapStringsSep "\n" (name: ''
          Mod+${name} ${
            lib.optionalString (name == "1") ''hotkey-overlay-title="切换工作区（数字键 1～5）"''
          } { focus-workspace "${name}"; }
          Mod+Shift+${name} ${
            lib.optionalString (name == "1") ''hotkey-overlay-title="发送窗口到工作区，不跟随（数字键 1～5）"''
          } { move-window-to-workspace "${name}" focus=false; }
          Mod+Ctrl+${name} ${
            lib.optionalString (name == "1") ''hotkey-overlay-title="发送窗口到工作区并跟随（数字键 1～5）"''
          } { move-window-to-workspace "${name}" focus=true; }
        '') workspaces}
        Mod+Slash hotkey-overlay-title="返回上一个工作区" { focus-workspace-previous; }
        Mod+Comma hotkey-overlay-title="切换到上一个工作区" { focus-workspace-up; }
        Mod+Period hotkey-overlay-title="切换到下一个工作区" { focus-workspace-down; }
    }
  '';
}
