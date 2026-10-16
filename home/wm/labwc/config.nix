{
  pkgs,
  appearance,
  ...
}:
let
  h = appearance.toHex;
  cp = appearance.catppuccin;

  # labwc 的 Execute 是 execvp 直启(不走 shell): 命令里不能有引号/命令替换,
  # 复杂逻辑一律放脚本里。键名 = xkb keysym; 修饰: W=Super S=Shift C=Ctrl A=Alt
  exec = key: cmd: {
    "@key" = key;
    action = {
      "@name" = "Execute";
      "@command" = cmd;
    };
  };
  # 纯 labwc 动作(无命令)
  act = key: name: {
    "@key" = key;
    action = {
      "@name" = name;
    };
  };
  goto = key: to: {
    "@key" = key;
    action = {
      "@name" = "GoToDesktop";
      "@to" = to;
    };
  };
  send = key: to: follow: {
    "@key" = key;
    action = {
      "@name" = "SendToDesktop";
      "@to" = to;
      "@follow" = follow;
    };
  };
  # 保留的 5 个工作区名
  ws = [
    "1"
    "2"
    "3"
    "4"
    "5"
  ];
in
{
  wayland.windowManager.labwc = {
    # 与旧会话 exec 自启对应: labwc autostart 只在会话启动时跑一次,
    # 配置重载(Reconfigure)不会重复拉起
    autostart = [
      # 输出缩放: labwc 不在 rc.xml 里管输出, scale 在会话启动时用 wlr-randr 设
      "wlr-randr --output eDP-1 --scale 1.25"
      # XWayland 高清渲染: 加载 Xft.dpi=120 (scale 1.25)
      "${pkgs.xrdb}/bin/xrdb -merge $HOME/.Xresources"
      # 由合成器启动 fcitx5(而非 fcitx5-daemon.service): 避免 daemon 在
      # wayland socket 就绪前启动导致输入法热键失效
      "fcitx5 -d"
      # Noctalia shell(状态栏/启动器/通知/锁屏/壁纸)
      "noctalia --daemon"
    ];

    # labwc 的会话环境文件: xkb 布局/选项在 rc.xml 里没有对应项,
    # 走 libxkbcommon 的 XKB_DEFAULT_* 环境变量
    environment = [
      "XKB_DEFAULT_LAYOUT=us"
      "XKB_DEFAULT_OPTIONS=caps:escape"
      # 会话标识只放合成器环境(不放 home.sessionVariables), 避免泄漏到 SSH/tty 会话
      "XDG_CURRENT_DESKTOP=labwc"
      "XDG_SESSION_DESKTOP=labwc"
      "XDG_SESSION_TYPE=wayland"
    ];

    rc = {
      core = {
        # 旧 sway gaps inner 5 的近似: MoveToEdge/贴边动作距窗口与输出边缘的间距
        gap = 5;
      };

      focus = {
        # 旧 sway: focus_follows_mouse no
        followMouse = "no";
      };

      keyboard = {
        # 底座: labwc 自带默认键 —— A-Tab/A-S-Tab 切窗、A-F4 关闭、
        # W-方向键 贴半屏/四分屏、A-Space 窗口菜单、音量/亮度键;
        # 下面的自定义键覆盖其中冲突项。窗口管理只迁了关窗/全屏两条,
        # 其余(移动焦点/移动窗口/resize/scratchpad 等)因 stacking 范式不迁。
        default = true;
        # 自定义键覆盖默认键(与 <default /> 冲突时以这里为准)。
        keybind = [
          # -- Noctalia IPC(沿用旧 sway 键位) --
          (exec "W-o" "noctalia msg bar-toggle")
          (exec "W-z" "noctalia msg panel-toggle launcher")
          (exec "W-v" "noctalia msg panel-toggle clipboard")
          (exec "W-S-p" "noctalia msg panel-toggle session")
          (exec "W-S-x" "noctalia msg session lock")

          # -- 截图(旧 sway); grimshot-savecopy = 交互截图并存 ~/Pictures 带时间戳 --
          (exec "Print" "flameshot gui")
          (exec "W-bracketleft" "grimshot-savecopy")
          (exec "W-bracketright" "grimshot --notify copy anything")
          # 旧 sway 键位: W-a 是截图(覆盖默认键的最大化)
          (exec "W-a" "grimshot-savecopy")

          # -- 应用启动(旧 sway) --
          (exec "W-Return" "kitty")
          (exec "W-S-Return" "kitty --class termfloat")
          (exec "W-S-b" "firefox")
          (exec "W-S-y" "qutebrowser")
          (exec "W-S-t" "Telegram")
          # 旧 sway 是"切 QQ 工作区+启动"; QQ 专属工作区已删, 只留启动
          (exec "W-S-q" "linuxqq-wayland-fix")
          (exec "A-S-s" "SPlayer-Next")
          (exec "W-S-v" "vesktop")

          # -- 媒体(旧 sway 的 mpc 三键; 音量/亮度键走 labwc 默认绑定) --
          (exec "XF86AudioPlay" "mpc -q toggle")
          (exec "XF86AudioNext" "mpc -q next")
          (exec "XF86AudioPrev" "mpc -q prev")

          # -- 窗口管理(旧 sway; 仅迁关窗, 全屏拆两档) --
          (act "W-q" "Close")
          # W-f = 主"全屏"键 → 带间隙的柔和最大化(四周留 gap + 投影)。
          # labwc 的 ToggleMaximize 是贴边无间隙; 想要间隙用 SnapToEdge center
          # (labwc FAQ 对"给最大化加间隙"的官方答案)。ToggleSnapToEdge 在
          # "贴合↔还原"间切换。
          {
            "@key" = "W-f";
            action = {
              "@name" = "ToggleSnapToEdge";
              "@direction" = "center";
            };
          }
          # W-S-f = 真全屏(贴边铺满, 盖住可用区)。
          (act "W-S-f" "ToggleFullscreen")
        ]
        # -- 工作区 1~5(旧 sway 工作区键位按精简后重映) --
        ++ map (n: goto "W-${n}" n) ws
        ++ map (n: send "W-S-${n}" n "no") ws
        ++ map (n: send "W-C-${n}" n "yes") ws
        ++ [
          # 当前↔上一个工作区(旧 back_and_forth)
          (goto "W-slash" "last")
          # 下一个/上一个工作区(旧 workspace next/prev)
          (goto "W-period" "right")
          (goto "W-comma" "left")
        ];
      };

      theme = {
        # Catppuccin Mocha Openbox 主题(见 theme.nix): 菜单/OSD/窗口配色
        name = "catppuccin-mocha";
        # 窗口投影: 补偿无标题栏后的层次感(阴影尺寸/颜色用主题默认)
        dropShadows = "yes";
        # 不带 place = 全部位置(菜单/OSD)统一字体
        font = {
          "@name" = appearance.font.name;
          "@size" = appearance.font.size;
        };
      };

      # 命名工作区: labwc 的工作区全局一份(不分屏); 名字供 GoToDesktop/
      # SendToDesktop 引用, 必须先声明(sway 是按需创建)
      desktops = {
        names = {
          name = [
            "1"
            "2"
            "3"
            "4"
            "5"
          ];
        };
      };

      # 旧 sway input "type:touchpad" 块
      libinput = {
        device = {
          "@category" = "touchpad";
          tap = "yes";
          naturalScroll = "yes";
          middleEmulation = "yes";
          dragLock = "no";
        };
      };

      # 鼠标绑定: 不用 <default/>(默认让左/中/右键都弹 root-menu, 且 labwc 的
      # process_press_mousebinding 会跑所有匹配绑定, 无法单条关闭某默认项)。
      # 显式定义: Frame(Super+拖动移动/缩放) + Client(点击聚焦) + Root(桌面)。
      # 桌面左/中键不绑定 = 不弹任何菜单, 只有右键弹 root-menu。
      mouse = {
        context = [
          # Super+拖动: 移动/缩放窗口
          {
            "@name" = "Frame";
            mousebind = [
              {
                "@button" = "W-Left";
                "@action" = "Press";
                action = [
                  {
                    "@name" = "Focus";
                  }
                  {
                    "@name" = "Raise";
                  }
                ];
              }
              {
                "@button" = "W-Left";
                "@action" = "Drag";
                action = {
                  "@name" = "Move";
                };
              }
              {
                "@button" = "W-Right";
                "@action" = "Press";
                action = [
                  {
                    "@name" = "Focus";
                  }
                  {
                    "@name" = "Raise";
                  }
                ];
              }
              {
                "@button" = "W-Right";
                "@action" = "Drag";
                action = {
                  "@name" = "Resize";
                };
              }
            ];
          }
          # 点击窗口聚焦(事件仍传给应用)
          {
            "@name" = "Client";
            mousebind = [
              {
                "@button" = "Left";
                "@action" = "Press";
                action = [
                  {
                    "@name" = "Focus";
                  }
                  {
                    "@name" = "Raise";
                  }
                ];
              }
              {
                "@button" = "Middle";
                "@action" = "Press";
                action = [
                  {
                    "@name" = "Focus";
                  }
                  {
                    "@name" = "Raise";
                  }
                ];
              }
              {
                "@button" = "Right";
                "@action" = "Press";
                action = [
                  {
                    "@name" = "Focus";
                  }
                  {
                    "@name" = "Raise";
                  }
                ];
              }
            ];
          }
          # 桌面: 只有右键弹菜单; 左/中键/滚轮不绑定 = 无任何动作
          {
            "@name" = "Root";
            mousebind = [
              {
                "@button" = "Right";
                "@action" = "Press";
                action = {
                  "@name" = "ShowMenu";
                  "@menu" = "root-menu";
                };
              }
            ];
          }
        ];
      };

      # ---- 窗口规则(旧 sway for_window) ----
      # 匹配维度: labwc 只有一个 identifier(Wayland 取 app_id, XWayland 取
      # WM_CLASS) + title, 且是大小写不敏感的 glob —— 旧的 app_id/class/instance
      # 三维 PCRE 各合并成一条; 旧 floating enable 在 labwc 里是空操作(全浮动),
      # 已省略。飞书/vesktop/v2rayn 等 X11 窗口的 instance/class 坍缩待真机
      # 实测(wev / xprop WM_CLASS)后收紧。
      windowRules = {
        windowRule = [
          # 全局去服务端标题栏(旧 sway: default_border pixel 3 = 无标题栏):
          # labwc 没有"只留边框"选项, 去 SSD 后窗口无标题栏(有 CSD 的应用仍画
          # 自己的标题栏)。窗口移动/缩放走默认鼠标绑定(Alt+拖动)与 W-方向键。
          {
            identifier = "*";
            serverDecoration = "no";
          }

          # (旧 sway for_window 的应用派发规则已随专属工作区一并移除:
          #  现在只保留 1~5 五个工作区, 新窗口按 labwc 默认策略放置)

          # -- 固定尺寸(旧 resize set width 960 / height 540) --
          {
            identifier = "termfloat";
            action = {
              "@name" = "ResizeTo";
              "@width" = "960";
              "@height" = "540";
            };
          }
          {
            identifier = "mpv";
            action = {
              "@name" = "ResizeTo";
              "@width" = "960";
              "@height" = "540";
            };
          }
          {
            identifier = "nemo";
            action = {
              "@name" = "ResizeTo";
              "@width" = "960";
              "@height" = "540";
            };
          }

          # -- 粘滞(旧 sticky enable): ToggleOmnipresent = 全工作区可见 --
          {
            identifier = "ncmpcpp";
            action = [
              {
                "@name" = "ResizeTo";
                "@width" = "960";
                "@height" = "540";
              }
              {
                "@name" = "ToggleOmnipresent";
              }
            ];
          }

          # -- 无边框/免打扰(旧 border none + no_focus 等) --
          # 旧 instance="bytedance-feishu": 飞书主窗(多为 XWayland)
          {
            identifier = "bytedance-feishu";
            serverDecoration = "no";
          }
          {
            identifier = "Main_Meeting";
            serverDecoration = "no";
          }
          # 旧 instance="ShareScreenFloatingPanelWindowBase": 飞书共享面板
          # (sticky + no_focus + 固定位置)
          {
            identifier = "ShareScreenFloatingPanelWindowBase";
            serverDecoration = "no";
            fixedPosition = "yes";
            ignoreFocusRequest = "yes";
            action = {
              "@name" = "ToggleOmnipresent";
            };
          }
          {
            identifier = "wemeetapp";
            serverDecoration = "no";
          }

          # -- flameshot(旧 border pixel 0 + move absolute 0 0; 旧 fullscreen
          #    disable 无对应, labwc 上 flameshot 需真机实测再调) --
          {
            identifier = "flameshot";
            serverDecoration = "no";
            action = {
              "@name" = "MoveTo";
              "@x" = "0";
              "@y" = "0";
            };
          }
        ];
      };
    };
  };
}
