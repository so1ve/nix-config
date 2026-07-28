{ pkgs, ... }:

{
  packages = with pkgs; [
    tinymist
    typst
    typstyle
  ];
}
