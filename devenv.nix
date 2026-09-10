{ lib, ... }:
{
  imports = [
    /home/ray/.config/devenv/ray/profiles/config.nix
    /home/ray/.config/devenv/ray/profiles/nix.nix
    /home/ray/.config/devenv/ray/profiles/lua.nix
    /home/ray/.config/devenv/ray/profiles/frontend.nix
    /home/ray/.config/devenv/ray/profiles/python.nix
  ]
  ++ lib.optional (builtins.pathExists ./devenv.local.nix) ./devenv.local.nix;
}
