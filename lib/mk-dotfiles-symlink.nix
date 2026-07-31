{
  config,
  name,
}:

config.lib.file.mkOutOfStoreSymlink
  "${config.home.homeDirectory}/Develop/nix-config/dotfiles/${name}"
