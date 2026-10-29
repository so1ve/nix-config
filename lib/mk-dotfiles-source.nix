{ config, copy }:

name:
if copy then
  ../dotfiles + "/${name}"
else
  config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Develop/nix-config/dotfiles/${name}"
