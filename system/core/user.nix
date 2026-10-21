{
  pkgs,
  me,
  ...
}:
{
  # tty1 getty 自动登录后，由 fish 启动 niri-session。
  services.getty.autologinUser = me.userName;

  # Set to true so passwords can be changed with `passwd`
  users.mutableUsers = true;
  users.users.root = {
    initialHashedPassword = me.initialHashedPassword;
  };
  users.users.${me.userName} = {
    initialHashedPassword = me.initialHashedPassword;
    shell = pkgs.fish;
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "video"
      "audio"
      "kvm"
    ];
  };
}
