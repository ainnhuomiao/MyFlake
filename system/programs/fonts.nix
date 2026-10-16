{ pkgs, appearance, ... }:
let
  nerdFonts = with pkgs.nerd-fonts; [
    # fonts name can get in `https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/data/fonts/nerdfonts/shas.nix`
    hack
    jetbrains-mono
    iosevka
    daddy-time-mono
    symbols-only
  ];
in
{
  fonts = {
    packages =
      with pkgs;
      [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
        noto-fonts-color-emoji
        maple-mono.NF-CN
      ]
      ++ nerdFonts;
    fontconfig = {
      enable = true;
      defaultFonts = {
        emoji = [ "Noto Color Emoji" ];
        serif = [
          appearance.font.name
          "Noto Serif CJK SC"
          "Noto Serif"
        ];
        sansSerif = [
          appearance.font.name
          "Noto Sans CJK SC"
          "Noto Sans"
        ];
        monospace = [
          appearance.font.name
          "Noto Sans Mono CJK SC"
        ];
      };
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <!-- Default system-ui fonts -->
          <match target="pattern">
            <test name="family">
              <string>system-ui</string>
            </test>
            <edit name="family" mode="prepend" binding="strong">
              <string>sans-serif</string>
            </edit>
          </match>

          <match target="pattern">
            <test name="lang" compare="contains">
              <string>zh</string>
            </test>
            <edit name="family" mode="prepend" binding="strong">
              <string>${appearance.font.name}</string>
            </edit>
          </match>

          <match target="pattern">
            <test name="lang" compare="contains">
              <string>en</string>
            </test>
            <edit name="family" mode="prepend" binding="strong">
              <string>${appearance.font.name}</string>
            </edit>
          </match>

          <match target="pattern">
            <test name="lang">
              <string>zh-HK</string>
            </test>
            <test name="family">
              <string>Noto Sans CJK SC</string>
            </test>
            <edit name="family" binding="strong">
              <string>Noto Sans CJK HK</string>
            </edit>
          </match>
        </fontconfig>
      '';
    };
  };
}
