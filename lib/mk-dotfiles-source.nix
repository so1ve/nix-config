{ config, copy }:

name:
if copy then
  ../dotfiles + "/${name}"
else
  config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Develop/projects/so1ve/nix-config/dotfiles/${name}"
