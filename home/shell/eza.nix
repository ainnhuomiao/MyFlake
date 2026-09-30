{ appearance, ... }:
let
  c = appearance.catppuccin;
  a = appearance.toAnsi;
  mkEzaColors =
    mapping:
    builtins.concatStringsSep ":" (
      builtins.attrValues (builtins.mapAttrs (key: hex: "${key}=${a hex}") mapping)
    );
in
{
  home.sessionVariables.EZA_COLORS = mkEzaColors {
    # file types
    di = c.blue; # directory
    ex = c.teal; # executable
    ln = c.sky; # symlink
    or = c.red; # broken symlink

    # permissions
    ur = c.yellow;
    uw = c.red;
    ux = c.teal;
    ue = c.teal;
    gr = c.yellow;
    gw = c.red;
    gx = c.teal;
    tr = c.yellow;
    tw = c.red;
    tx = c.teal;

    # metadata
    sn = c.blue; # size number
    sb = c.overlay0; # size unit
    da = c.overlay0; # date
    uu = c.blue; # current user
    un = c.overlay0; # other user
    gu = c.mauve; # current group
    gn = c.overlay0; # other group
  };
}
