{ lib, appearance, ... }:

let
  # 与桌面、终端和编辑器共享 lib/appearance.nix 的语义颜色。
  cp = appearance.catppuccin;
  # catppuccin/tty 的 16 色映射（themes/mocha.txt，tty.tera 顺序）：
  # color0 用 base 作内核控制台默认背景，color7 用 subtext1 作默认前景。
  ttyPalette = [
    cp.base # 0: base
    cp.red # 1: red
    cp.green # 2: green
    cp.yellow # 3: yellow
    cp.blue # 4: blue
    cp.pink # 5: pink
    cp.teal # 6: teal
    cp.subtext1 # 7: subtext1
    cp.surface1 # 8: surface1
    cp.red # 9: bright red
    cp.green # 10: bright green
    cp.yellow # 11: bright yellow
    cp.blue # 12: bright blue
    cp.pink # 13: bright pink
    cp.teal # 14: bright teal
    cp.subtext0 # 15: subtext0
  ];
  kmsconPaletteNames = [
    "palette-black"
    "palette-red"
    "palette-green"
    "palette-yellow"
    "palette-blue"
    "palette-magenta"
    "palette-cyan"
    "palette-light-grey"
    "palette-dark-grey"
    "palette-light-red"
    "palette-light-green"
    "palette-light-yellow"
    "palette-light-blue"
    "palette-light-magenta"
    "palette-light-cyan"
    "palette-white"
  ];
in
{
  services = {
    dbus.enable = true;
    openssh.enable = true;
    # 用户态 TTY 终端，pango+fontconfig 渲染，支持中文显示
    kmscon = {
      enable = true;
      config = {
        font-name = "Maple Mono NF CN, Noto Sans Mono CJK SC";
        font-size = 14;
        # Catppuccin ${appearance.catppuccinVariant} 配色（kmscon.conf palette=custom + palette-* 键）
        palette = "custom";
        palette-foreground = appearance.toRgb cp.text;
        palette-background = appearance.toRgb cp.base;
      }
      // builtins.listToAttrs (
        lib.zipListsWith (name: color: {
          inherit name;
          value = appearance.toRgb color;
        }) kmsconPaletteNames ttyPalette
      );
    };
  };

  # 内核控制台（启动早期 + tty1 getty）用同一 16 色调色板，
  # 由 console.colors 生成 vt.default_red/grn/blu 内核参数
  console.colors = ttyPalette;

  # ly 已移除; tty1 保留真实 getty 并 autologin(fish loginShellInit 守卫 exec sway),
  # 直接启动进 sway; kmscon 仍接管 VTs 2–6 渲染中文 TTY
  systemd.suppressedSystemUnits = lib.mkForce [ ];
  systemd.targets.getty.wants = lib.mkForce [ "getty@tty1.service" ];

  # stateVersion 记录首次安装时的 NixOS release(当前 stable: 26.05),升级后不要随意改动
  system.stateVersion = "26.05";
}
