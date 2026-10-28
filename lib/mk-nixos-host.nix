{
  config,
  inputs,
  lib,
}:

let
  inherit (lib) optional;

  featureRegistry = import ./feature-registry.nix {
    features = config.ray.features;
    inherit lib;
  };

  specialArgsFor = host: {
    inherit inputs;
    featureEnabled = featureRegistry.enabled host.features;
    user = config.ray.registry.users.${host.username};
    inherit (host)
      hostname
      homeStateVersion
      stateVersion
      system
      username
      ;
  };

  homeManagerModule = host: homeModules: {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = specialArgsFor host;
      users.${host.username} =
        { config, pkgs, ... }:
        {
          imports = homeModules;
          _module.args = {
            mkDotfilesSource = import ./mk-dotfiles-source.nix {
              inherit config;
              inherit (host) dotfilesMode;
            };
            focusOrLaunch = import ./mk-focus-or-launch.nix {
              inherit inputs pkgs;
            };
          };
        };
      backupFileExtension = "home-manager.backup";
    };
  };
in
host:
let
  features = featureRegistry.select host;
  modulesFor =
    kind:
    lib.mapAttrsToList (name: feature: feature.${kind} host.features.${name}) (
      lib.filterAttrs (_: feature: feature.${kind} != null) features
    );
  nixosModules = modulesFor "nixos";
  homeModules = modulesFor "home";
in
inputs.nixpkgs.lib.nixosSystem {
  inherit (host) system;
  specialArgs = specialArgsFor host;
  modules =
    nixosModules
    ++ host.modules
    ++ optional (homeModules != [ ]) inputs.home-manager.nixosModules.home-manager
    ++ optional (homeModules != [ ]) (homeManagerModule host homeModules);
}
