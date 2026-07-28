{ pkgs, ... }:

{
  packages = with pkgs; [
    typst
    typstyle
  ];
}
