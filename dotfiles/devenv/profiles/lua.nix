{ pkgs, ... }:

{
  packages = with pkgs; [
    lua
    luarocks
  ];
}
