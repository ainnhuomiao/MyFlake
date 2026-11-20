{
  time.timeZone = "Asia/Shanghai";

  i18n = {
    defaultLocale = "zh_CN.UTF-8";
    extraLocaleSettings = {
      LC_ALL = "zh_CN.UTF-8";
      LANGUAGE = "zh_CN.UTF-8:en_US.UTF-8";
    };
    supportedLocales = [
      "C.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
      "zh_TW.UTF-8/UTF-8"
    ];
  };

  services.xserver.xkb.options = "caps:escape";
  console.useXkbConfig = true;
}
