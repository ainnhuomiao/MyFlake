{ pkgs, ... }:
{
  home.packages = with pkgs.haskellPackages; [
    ghc
    haskell-language-server
    cabal-install
  ];
}
