{
  programs = {
    fish.enable = true;
    git = {
      enable = true;
      config.safe.directory = [ "/home/huomiao/MyFlake" ];
    };
    nh = {
      enable = true;
      flake = "/home/huomiao/MyFlake";
    };
  };
}
