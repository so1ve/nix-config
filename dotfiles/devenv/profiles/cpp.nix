{ pkgs, ... }:

{
  packages = with pkgs; [
    ccache
    clang-tools
    cmake
    gcc
    gdb
    ninja
    pkg-config
  ];
}
