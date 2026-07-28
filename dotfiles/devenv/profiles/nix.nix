{ pkgs, ... }:

{
  packages = with pkgs; [
    deadnix
    nixd
    nixfmt
    statix
  ];
}
