{
  pkgs,
  appearance,
  ...
}:
let
  h = appearance.toHex;
  cp = appearance.catppuccin.${appearance.catppuccinVariant};
in
{
  services.swayidle = {
    enable = true;
    events = {
      "before-sleep" = "${pkgs.systemd}/bin/loginctl lock-session";
    };
  };
  wayland.windowManager.sway = {
    config = null;
    extraConfig = ''
      #---------p
      # mod key #
      #---------#
      set $mod Mod4
      set $ipc noctalia msg

      #-------------------#
      # swayfx 毛玻璃效果 #
      #-------------------#
      blur enable
      blur_radius 5
      blur_passes 3
      blur_noise 0.01
      # 窗口打开/关闭动画(0-5000ms,swayfx 特有)
      animation_duration_ms 250

      #---------------#
      # bar toggle    #
      #---------------#
      bindsym $mod+o exec $ipc bar-toggle

      #-------------------------------------------#
      # switch between current and last workspace #
      #-------------------------------------------#
      #slash(/)
      bindsym $mod+slash workspace back_and_forth

      #-------------------------------#
      # Switch to prev/next workspace #
      #-------------------------------#
      #comma(,) period(.)
      bindsym $mod+period workspace next
      bindsym $mod+comma workspace prev

      #-----------------------------#
      #           Misc              #
      #-----------------------------#
      output * adaptive_sync on
      output eDP-1 scale 1.25

      default_border pixel 3
      default_floating_border pixel 3
      gaps inner  5
      gaps outer  0
      bindsym $mod+shift+g exec swaymsg gaps outer all set 0 && swaymsg gaps inner all set 5
      bindsym $mod+g exec swaymsg gaps outer all set 0 && swaymsg gaps inner all set 0

      # Activate smart borders (always)
      smart_borders on

      #------------------------------#
      # Always float certain windows #
      #------------------------------#
      #swaymsg -t get_tree | grep app_id
      for_window [app_id="pop-up"]                     floating enable
      for_window [app_id="bubble"]                     floating enable
      for_window [app_id="task_dialog"]                floating enable
      for_window [app_id="Preferences"]                floating enable
      for_window [app_id="dialog"]                     floating enable
      for_window [app_id="menu"]                       floating enable
      for_window [app_id="Organizer"]                  floating enable
      for_window [app_id="About"]                      floating enable
      for_window [app_id="toolbox"]                    floating enable
      for_window [app_id="page-info"]                  floating enable
      for_window [app_id="webconsole"]                 floating enable
      for_window [app_id="Authy"]                      floating enable
      for_window [app_id="termfloat"]                  floating enable
      for_window [app_id="termfloat"]                  resize set height 540
      for_window [app_id="termfloat"]                  resize set width 960
      for_window [app_id="mpv"]                        floating enable
      for_window [app_id="mpv"]                        resize set height 540
      for_window [app_id="mpv"]                        resize set width 960
      for_window [app_id="nemo"]                   floating enable
      for_window [app_id="nemo"]                   resize set height 540
      for_window [app_id="nemo"]                   resize set width 960
      for_window [class="Emulator"]                   floating enable
      for_window [app_id="flameshot"] border pixel 0, floating enable, fullscreen disable, move absolute position 0 0
      for_window [title="flameshot-pin"]                   floating enable

      #-------------------------------------------#
      # Meeting & Screen Sharing Adaptations      #
      #-------------------------------------------#
      for_window [instance="bytedance-feishu"] floating enable, border none
      for_window [instance="Main_Meeting"] floating enable, border none
      for_window [instance="ShareScreenFloatingPanelWindowBase"] floating enable, border none, sticky enable, focus_follows_mouse no, no_focus
      for_window [app_id="wemeetapp"] floating enable, border none

      #-------------------------------------------------------#
      # Sticky floating windows(sticky enable|disable|toggle) #
      #-------------------------------------------------------#
      for_window [app_id="ncmpcpp"]                  floating enable
      for_window [app_id="ncmpcpp"]                  sticky enable
      for_window [app_id="ncmpcpp"]                  resize set height 540
      for_window [app_id="ncmpcpp"]                  resize set width 960

      #-----------------#
      # Program Opacity #
      #-----------------#
      for_window [app_id="telegram"]                    opacity 0.95

      #------------------------------------------#
      # Placing software in a specific workspace #
      #------------------------------------------#
      for_window [app_id="telegram"] move --no-auto-back-and-forth container to workspace TG
      for_window [app_id="telegram"] focus
      for_window [app_id="(?i)^wechat$"] move --no-auto-back-and-forth container to workspace WC
      for_window [app_id="(?i)^wechat$"] focus
      for_window [class="(?i)^wechat$"] move --no-auto-back-and-forth container to workspace WC
      for_window [class="(?i)^wechat$"] focus
      for_window [app_id="com.github.th_ch.youtube_music"] move --no-auto-back-and-forth container to workspace Music
      for_window [app_id="com.github.th_ch.youtube_music"] focus
      for_window [app_id="firefox"] move --no-auto-back-and-forth container to workspace Ff
      for_window [app_id="firefox"] focus
      for_window [app_id="org.qutebrowser.qutebrowser"] move --no-auto-back-and-forth container to workspace Qb
      for_window [app_id="org.qutebrowser.qutebrowser"] focus
      for_window [app_id="QQ"] move --no-auto-back-and-forth container to workspace QQ
      for_window [app_id="QQ"] focus
      for_window [app_id="(?i)^vesktop$"] move --no-auto-back-and-forth container to workspace VT
      for_window [app_id="(?i)^vesktop$"] focus
      for_window [class="(?i)^vesktop$"] move --no-auto-back-and-forth container to workspace VT
      for_window [class="(?i)^vesktop$"] focus
      for_window [app_id="(?i)^top\.imsyy\.splayer_next$"] move --no-auto-back-and-forth container to workspace SPlayer
      for_window [app_id="(?i)^top\.imsyy\.splayer_next$"] focus
      for_window [class="(?i)^top\.imsyy\.splayer_next$"] move --no-auto-back-and-forth container to workspace SPlayer
      for_window [class="(?i)^top\.imsyy\.splayer_next$"] focus
      for_window [app_id="md.Obsidian"] move --no-auto-back-and-forth container to workspace Obsidian
      for_window [app_id="md.Obsidian"] focus
      for_window [class="(?i)^v2rayn$"] move --no-auto-back-and-forth container to workspace V2rayN
      for_window [instance="(?i)^v2rayn$"] move --no-auto-back-and-forth container to workspace V2rayN
      for_window [class="(?i)^v2rayn$"] focus

      #---------------------#
      # Focus follows mouse #
      #---------------------#
      focus_follows_mouse no

      #-----------#
      # Autostart #
      #-----------#
      exec_always  ${pkgs.autotiling}/bin/autotiling
      # XWayland 高清渲染: 加载 Xft.dpi=120 (scale 1.25)
      exec_always ${pkgs.xrdb}/bin/xrdb -merge $HOME/.Xresources
      # 由 sway 启动 fcitx5(而非 fcitx5-daemon.service): 避免 daemon 在
      # sway 的 wayland socket 就绪前启动导致输入法热键失效 (ly 登录时代出现)
      exec_always --no-startup-id fcitx5 -d
      # Noctalia shell: 用 exec 而非 exec_always, 避免配置 reload 时重复实例
      exec --no-startup-id noctalia --daemon

      #------------------------------#
      # Make capslock work as escape #
      #------------------------------#
      input "type:keyboard" {
      xkb_layout us
      xkb_options caps:escape
      }

      #----------------------------------------#
      # window colours: border background text #
      #----------------------------------------#
      # catppuccin ${appearance.catppuccinVariant} 窗口色
      client.focused          ${h cp.color4} ${h cp.color4} #ffffff
      client.unfocused        ${h cp.bg} ${h cp.color0} #888888
      client.focused_inactive ${h cp.bg} ${h cp.color0} #888888
      client.placeholder      ${h cp.bg} ${h cp.color0} #888888
      client.urgent           ${h cp.color1} ${h cp.color1} #ffffff
      client.background       ${h cp.bg}

      #-----------------------------------#
      # Home row direction keys, like vim #
      #-----------------------------------#
      set $left  h
      set $down  j
      set $up    k
      set $right l

      #----------------------------------#
      # Your preferred terminal emulator #
      #----------------------------------#
      set $term kitty

      #-------------------------------------#
      # Your preferred application launcher #
      #-------------------------------------#
      # Note: pass the final command to swaymsg so that the resulting window can be opened
      # on the original workspace that the command was run on.
      # 启动器由 Noctalia 提供($mod+z -> panel-toggle launcher)

      #-----------#
      # WallPaper #
      #-----------#
      # 静态壁纸与视频壁纸均由 Noctalia(壁纸管理器 + 官方 noctalia/mpvpaper 插件)托管,
      # 切换脚本见 home/wall/share_scripts.nix,不再使用 swaybg/output bg。

      #-------------------------------------------------#
      # Control volume,monitor brightness,media players #
      #-------------------------------------------------#
      bindsym XF86AudioRaiseVolume exec pamixer -i 5
      bindsym XF86AudioLowerVolume exec pamixer -d 5
      bindsym XF86AudioMute exec pamixer -t
      bindsym XF86AudioMicMute exec pamixer --default-source -t
      bindsym XF86MonBrightnessUp exec brightnessctl set +5%
      bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
      bindsym XF86AudioPlay exec mpc -q toggle
      bindsym XF86AudioNext exec mpc -q next
      bindsym XF86AudioPrev exec mpc -q prev


      #---------------------#
      # Input configuration #
      #---------------------#
      # You can get the names of your inputs by running: swaymsg -t get_inputs
      # Read `man 5 sway-input` for more information about this section.
      input "type:touchpad" {
      dwt enabled
      tap enabled
      natural_scroll enabled
      middle_emulation enabled
      drag_lock disabled
      }


      #----------------#
      # Key bindings --#
      #----------------#
      # Start a terminal
      bindsym $mod+Return exec $term
      bindsym $mod+Shift+Return exec kitty --class="termfloat"

      # quick start some applications
      bindsym Alt+Shift+s exec --no-startup-id         SPlayer-Next
      bindsym $mod+Shift+b exec --no-startup-id        firefox
      bindsym $mod+Shift+y exec --no-startup-id        qutebrowser
      bindsym $mod+Shift+x exec --no-startup-id        $ipc session lock
      bindsym $mod+Shift+t exec --no-startup-id        Telegram
      bindsym $mod+bracketleft  exec --no-startup-id   grimshot --notify savecopy anything ~/Pictures/$(date "+%Y-%m-%d"T"%H_%M_%S").png
      bindsym $mod+bracketright exec --no-startup-id   grimshot --notify copy anything
      bindsym $mod+a exec --no-startup-id              grimshot --notify savecopy anything ~/Pictures/$(date "+%Y-%m-%d"T"%H_%M_%S").png
      bindsym Print exec --no-startup-id               flameshot gui
      bindsym $mod+Shift+q workspace QQ, exec --no-startup-id qq
      bindsym Alt+Shift+q workspace QQ
      bindsym Alt+Shift+t workspace TG
      bindsym Alt+Shift+w workspace WC
      bindsym Alt+Shift+b workspace Ff
      bindsym Alt+Shift+y workspace Qb

      # wallpaper
      bindsym $mod+Shift+w exec --no-startup-id        wallpaper_random
      bindsym $mod+Ctrl+w exec --no-startup-id         dynamic_wallpaper
      bindsym $mod+Ctrl+Shift+w exec --no-startup-id   default_wall
      # 视频壁纸选择器(官方 noctalia/mpvpaper 插件面板:选片/暂停/清除)
      bindsym $mod+Ctrl+v exec --no-startup-id         video_wallpaper
      # 清除视频壁纸,回到静态壁纸
      bindsym $mod+Ctrl+Shift+v exec --no-startup-id   video_wallpaper_clear


      # Kill focused window
      bindsym $mod+q kill

      # Start your launcher
      bindsym $mod+z exec $ipc panel-toggle launcher

      # Clipboard history
      bindsym $mod+v exec $ipc panel-toggle clipboard

      # Start your powermenu
      bindsym $mod+Shift+p exec $ipc panel-toggle session

      # Reload the configuration file
      bindsym $mod+Shift+c reload

      # Exit sway (logs you out of your Wayland session)
      bindsym $mod+Shift+e exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -B 'Yes, exit sway' 'swaymsg exit'

      # Drag floating windows by holding down Super and left mouse button.
      # Resize them with right mouse button + Super.
      # Despite the name, also works for non-floating windows.
      # Change normal to inverse to use left mouse button for resizing and right
      # mouse button for dragging.
      floating_modifier Mod4 normal

      #----------------#
      # Moving around: #
      #----------------#
      # Move your focus around
      bindsym $mod+$left focus left
      bindsym $mod+$down focus down
      bindsym $mod+$up focus up
      bindsym $mod+$right focus right
      # Or use $mod+[up|down|left|right]
      bindsym $mod+Left focus left
      bindsym $mod+Down focus down
      bindsym $mod+Up focus up
      bindsym $mod+Right focus right

      # Move the focused window with the same, but add Shift
      bindsym $mod+Shift+$left move left
      bindsym $mod+Shift+$down move down
      bindsym $mod+Shift+$up move up
      bindsym $mod+Shift+$right move right
      # Ditto, with arrow keys
      bindsym $mod+Shift+Left move left
      bindsym $mod+Shift+Down move down
      bindsym $mod+Shift+Up move up
      bindsym $mod+Shift+Right move right
      #-------------#
      # Workspaces: #
      #-------------#
      # Switch to workspace
      bindsym $mod+1 workspace 1:壹
      bindsym $mod+2 workspace 2:贰
      bindsym $mod+3 workspace 3:叁
      bindsym $mod+4 workspace 4:肆
      bindsym $mod+5 workspace 5:伍
      bindsym $mod+6 workspace 6:陆
      bindsym $mod+7 workspace 7:柒
      bindsym $mod+8 workspace 8:捌
      bindsym $mod+9 workspace 9:玖
      bindsym $mod+0 workspace 10:拾
      bindsym Mod1+Shift+v workspace VT
      bindsym $mod+Shift+v exec vesktop
      # Move focused container to workspace
      bindsym $mod+Shift+1 move container to workspace 1:壹
      bindsym $mod+Shift+2 move container to workspace 2:贰
      bindsym $mod+Shift+3 move container to workspace 3:叁
      bindsym $mod+Shift+4 move container to workspace 4:肆
      bindsym $mod+Shift+5 move container to workspace 5:伍
      bindsym $mod+Shift+6 move container to workspace 6:陆
      bindsym $mod+Shift+7 move container to workspace 7:柒
      bindsym $mod+Shift+8 move container to workspace 8:捌
      bindsym $mod+Shift+9 move container to workspace 9:玖
      bindsym $mod+Shift+0 move container to workspace 10:拾
      # move focused container to workspace(follow)
      bindsym $mod+Ctrl+1 move container to workspace 1:壹, workspace 1:壹
      bindsym $mod+Ctrl+2 move container to workspace 2:贰, workspace 2:贰
      bindsym $mod+Ctrl+3 move container to workspace 3:叁, workspace 3:叁
      bindsym $mod+Ctrl+4 move container to workspace 4:肆, workspace 4:肆
      bindsym $mod+Ctrl+5 move container to workspace 5:伍, workspace 5:伍
      bindsym $mod+Ctrl+6 move container to workspace 6:陆, workspace 6:陆
      bindsym $mod+Ctrl+7 move container to workspace 7:柒, workspace 7:柒
      bindsym $mod+Ctrl+8 move container to workspace 8:捌, workspace 8:捌
      bindsym $mod+Ctrl+9 move container to workspace 9:玖, workspace 9:玖
      bindsym $mod+Ctrl+0 move container to workspace 10:拾, workspace 10:拾
      # Note: workspaces can have any name you want, not just numbers.
      # We just use 1-10 as the default.
      #---------------#
      # Layout stuff: #
      #---------------#
      # You can "split" the current object of your focus with
      # $mod+semicolon or $mod+apostrophe, for horizontal and vertical splits
      # respectively.
      bindsym $mod+semicolon splitv
      bindsym $mod+apostrophe splith

      # Switch the current container between different layout styles
      bindsym $mod+s layout stacking
      bindsym $mod+w layout tabbed
      bindsym $mod+e layout toggle split

      # Make the current focus fullscreen
      bindsym $mod+f fullscreen

      # Toggle the current focus between tiling and floating mode
      bindsym $mod+Shift+space floating toggle

      # Swap focus between the tiling area and the floating area
      bindsym $mod+space focus mode_toggle

      # Move focus to the parent container
      bindsym $mod+p focus parent
      # Move focus the child container
      bindsym $mod+c focus child
      #-------------#
      # Scratchpad: #
      #-------------#
      ## hide | show window(minus is "-" and plus is "+".)
      bindsym $mod+minus move scratchpad
      bindsym $mod+equal scratchpad show

      #----------------------#
      # Resizing containers: #
      #----------------------#
      bindsym $mod+r mode "resize"
      mode "resize" {
      # left will shrink the containers width
      # right will grow the containers width
      # up will shrink the containers height
      # down will grow the containers height
      bindsym $left resize shrink width 10px
      bindsym $up resize grow height 10px
      bindsym $down resize shrink height 10px
      bindsym $right resize grow width 10px

      # Ditto, with arrow keys
      bindsym Left resize shrink width 10px
      bindsym Up resize grow height 10px
      bindsym Down resize shrink height 10px
      bindsym Right resize grow width 10px

      # Return to default mode
      bindsym Return mode "default"
      bindsym Escape mode "default"
      }
      ## Better to resize window
      bindsym Shift+Ctrl+h             resize shrink width  5 px or 5 ppt
      bindsym Shift+Ctrl+k             resize grow   height 5 px or 5 ppt
      bindsym Shift+Ctrl+j             resize shrink height 5 px or 5 ppt
      bindsym Shift+Ctrl+l             resize grow   width  5 px or 5 ppt
      bindsym Shift+Ctrl+Left          resize shrink width  5 px or 5 ppt
      bindsym Shift+Ctrl+Up            resize grow   height 5 px or 5 ppt
      bindsym Shift+Ctrl+Down          resize shrink height 5 px or 5 ppt
      bindsym Shift+Ctrl+Right         resize grow   width  5 px or 5 ppt

    '';
  };
}
