{ config, dotfilesMode }:

name:
if dotfilesMode == "symlink" then
  config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Develop/nix-config/dotfiles/${name}"
else
  ../dotfiles + "/${name}"
