{ pkgs, ... }:

{
  packages = with pkgs; [
    ccache
    cmake
    gcc
    gdb
    ninja
    pkg-config
  ];
}
