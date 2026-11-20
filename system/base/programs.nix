{ me, ... }:
let
  flakeDirectory = "/home/${me.userName}/MyFlake";
in
{
  programs = {
    fish.enable = true;
    git = {
      enable = true;
      config.safe.directory = [ flakeDirectory ];
    };
    nh = {
      enable = true;
      flake = flakeDirectory;
    };
  };
}
