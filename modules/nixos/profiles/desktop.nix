{ ... }:

{
  imports = [
    ../desktop/common.nix
    ../desktop/niri.nix
    ../desktop/noctalia.nix
    ../desktop/plasma.nix
  ];

  home-manager.sharedModules = [
    ../../../home/profiles/niri.nix
    ../../../home/profiles/noctalia.nix
    ../../../home/profiles/plasma.nix
  ];
}
