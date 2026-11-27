{
  me,
  pkgs,
  ...
}:

{
  virtualisation.docker = {
    enable = true;
  };

  users.users.${me.userName}.extraGroups = [ "docker" ];

  environment.systemPackages = with pkgs; [
    distrobox
    lazydocker
  ];
}
