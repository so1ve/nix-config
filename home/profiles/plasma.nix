{ pkgs, ... }:

{
  home.packages = [
    pkgs.kdePackages.kate
  ];
}
