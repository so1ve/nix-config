{ pkgs, ... }:

{
  packages = with pkgs; [
    deadnix
    statix
  ];
}
