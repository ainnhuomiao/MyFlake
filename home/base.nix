# 物理机与 WSL 共用的 Home Manager 基础设置
{
  me,
  ...
}:
{
  home = {
    username = me.userName;
    homeDirectory = "/home/${me.userName}";
    language.base = "en_US.UTF-8";
    shell = {
      enableFishIntegration = true;
      enableBashIntegration = true;
    };
    sessionVariables = {
      NIX_AUTO_RUN = "1";
    };
  };
  programs = {
    home-manager.enable = true;
  };

  home.enableNixpkgsReleaseCheck = false;
  home.stateVersion = "25.11";
}
