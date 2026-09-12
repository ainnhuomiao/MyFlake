{
  programs = {
    fish.enable = true;
    git = {
      enable = true;
      config.safe.directory = [ "*" ];
    };
    nh = {
      enable = true;
      flake = "/home/huomiao/MyFlake";
    };
  };
}
