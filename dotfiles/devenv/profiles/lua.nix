{ pkgs, ... }:

{
  packages = with pkgs; [
    lua
    lua-language-server
    luarocks
    stylua
  ];
}
