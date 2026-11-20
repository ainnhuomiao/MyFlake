{
  config,
  appearance,
  ...
}:
let
  c = appearance.catppuccin;
  h = appearance.toHex;
in
{
  programs.go-musicfox = {
    enable = true;
    settings = {
      startup = {
        enable = false;
      };
      main = {
        downloadDir = "${config.home.homeDirectory}/Music";
      };
      theme = {
        primaryColor = h c.text;
      };
    };
  };
}
