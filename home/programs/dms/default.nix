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
  theme = {
    name = "Catppuccin ${appearance.catppuccinName}";
    primary = h cp.mauve;
    primaryText = h cp.base;
    primaryContainer = h cp.surface1;
    secondary = h cp.blue;
    surface = h cp.base;
    surfaceText = h cp.text;
    surfaceVariant = h cp.surface0;
    surfaceVariantText = h cp.subtext1;
    surfaceTint = h cp.mauve;
    background = h cp.mantle;
    backgroundText = h cp.text;
    outline = h cp.overlay0;
    surfaceContainer = h cp.surface0;
    surfaceContainerHigh = h cp.surface1;
    error = h cp.red;
    warning = h cp.yellow;
    info = h cp.sky;
  };
  settings = pkgs.writeText "dms-settings.json" (
    builtins.toJSON {
      currentThemeName = "custom";
      currentThemeCategory = "custom";
      customThemeFile = "${config.xdg.configHome}/DankMaterialShell/themes/catppuccin.json";
      fontFamily = appearance.font.name;
      monoFontFamily = appearance.font.name;
      clockFormat = "24h";
      lockBeforeSuspend = true;
      loginctlLockIntegration = true;
      lockPamPath = "/etc/pam.d/dankshell";
      lockPamExternallyManaged = true;
      runUserMatugenTemplates = false;
    }
  );
  session = pkgs.writeText "dms-session.json" (
    builtins.toJSON {
      isLightMode = false;
      locale = "zh_CN";
      wallpaperPath = "${config.home.homeDirectory}/${appearance.wallpapersDir}/default.png";
      wallpaperCyclingEnabled = false;
      wallpaperCyclingRandom = true;
    }
  );
in
{
  # DMS 的服务与依赖由 NixOS programs.dms-shell 安装；这里管理主题和首次登录默认值。
  xdg.configFile."DankMaterialShell/themes/catppuccin.json".text = builtins.toJSON {
    dark = theme;
    light = theme;
  };

  # settings/session 必须可写，DMS 设置界面会保存它们。只在首次创建时复制，后续不覆盖。
  home.activation.dmsDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg "${config.xdg.configHome}/DankMaterialShell"} \
      ${lib.escapeShellArg "${config.xdg.stateHome}/DankMaterialShell"}
    if [ ! -e ${lib.escapeShellArg "${config.xdg.configHome}/DankMaterialShell/settings.json"} ]; then
      run install -m600 ${settings} ${lib.escapeShellArg "${config.xdg.configHome}/DankMaterialShell/settings.json"}
    fi
    if [ ! -e ${lib.escapeShellArg "${config.xdg.stateHome}/DankMaterialShell/session.json"} ]; then
      run install -m600 ${session} ${lib.escapeShellArg "${config.xdg.stateHome}/DankMaterialShell/session.json"}
    fi
  '';
}
