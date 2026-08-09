{ pkgs, ... }:

{
  languages.haskell.enable = true;

  packages = with pkgs; [
    fourmolu
    haskellPackages.cabal-fmt
    hlint
  ];
}
