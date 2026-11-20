{ appearance, ... }:
let
  c = appearance.catppuccin;
  h = appearance.toHex;
in
{
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        theme = {
          activeBorderColor = [
            (h c.sapphire)
            "bold"
          ];
          inactiveBorderColor = [ (h c.overlay0) ];
          searchingActiveBorderColor = [
            (h c.yellow)
            "bold"
          ];
          optionsTextColor = [ (h c.blue) ];
          selectedLineBgColor = [ (h c.surface0) ];
          selectedRangeBgColor = [ (h c.surface0) ];
          cherryPickedCommitFgColor = [ (h c.green) ];
          cherryPickedCommitBgColor = [ (h c.lavender) ];
          unstagedChangesColor = [ (h c.red) ];
          defaultFgColor = [ (h c.text) ];
        };
      };
    };
  };
}
