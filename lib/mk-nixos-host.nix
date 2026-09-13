{
  config,
  inputs,
  lib,
}:

let
  inherit (lib) filter optional;

  featureRegistry = import ./feature-registry.nix {
    features = config.ray.features;
    inherit lib;
  };

  modulesFor =
    kind: features: map (feature: feature.${kind}) (filter (feature: feature.${kind} != null) features);

  mkDotfilesSymlink = import "${inputs.self}/lib/mk-dotfiles-symlink.nix";
  mkFocusOrLaunch = import "${inputs.self}/lib/mk-focus-or-launch.nix" { inherit inputs; };
  mkAppImage = import "${inputs.self}/lib/mk-appimage.nix" { inherit lib; };

  specialArgsFor = host: {
    inherit
      inputs
      mkAppImage
      mkDotfilesSymlink
      mkFocusOrLaunch
      ;
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
      users.${host.username}.imports = homeModules;
      backupFileExtension = "home-manager.backup";
    };
  };
in
host:
let
  features = featureRegistry.select host;
  nixosModules = modulesFor "nixos" features;
  homeModules = modulesFor "home" features;
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
