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
              copy = host.isServer;
            };
            focusOrLaunch = import ./mk-focus-or-launch.nix { inherit pkgs; };
          };
        };
      backupFileExtension = "home-manager.backup";
    };
  };
in
host:
let
  instances = featureRegistry.select host;
  modulesFor =
    kind:
    map (instance: instance.feature.${kind} { inherit (instance) name settings; }) (
      lib.filter (instance: instance.feature.${kind} != null) instances
    );
  nixosModules = modulesFor "nixos";
  homeModules = modulesFor "home";
in
inputs.nixpkgs.lib.nixosSystem {
  inherit (host) system;
  specialArgs = specialArgsFor host;
  modules = [
    { nixpkgs.overlays = [ inputs.so1ve.overlays.default ]; }
  ]
  ++ nixosModules
  ++ host.modules
  ++ optional (homeModules != [ ]) inputs.home-manager.nixosModules.home-manager
  ++ optional (homeModules != [ ]) (homeManagerModule host homeModules);
}
