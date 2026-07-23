{ ... }:

{
  imports = [
    ../desktop/common.nix
    ../desktop/plasma.nix
  ];

  home-manager.sharedModules = [
    ../../../home/profiles/plasma.nix
  ];
}
