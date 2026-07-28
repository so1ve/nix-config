{ pkgs, ... }:

{
  packages = with pkgs; [
    texlab
    texlivePackages.latexindent
  ];
}
