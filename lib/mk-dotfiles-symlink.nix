{
  config,
  name,
}:

config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/${name}"
