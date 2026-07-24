{ ... }:

{
  imports = [
    ../desktop/common.nix
    ../desktop/input-method.nix
    ../desktop/niri.nix
    ../desktop/noctalia.nix
    ../desktop/plasma.nix
  ];

  home-manager.sharedModules = [
    ../../../home/profiles/input-method.nix
    ../../../home/profiles/niri.nix
    ../../../home/profiles/noctalia.nix
    ../../../home/profiles/plasma.nix
  ];
}
