{
  pkgs,
  me,
  ...
}:
{
  # Boot straight into sway via tty1 getty autologin (ly removed)
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
