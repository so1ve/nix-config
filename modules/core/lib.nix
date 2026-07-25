{
  config,
  inputs,
  lib,
  self,
  ...
}:

let
  inherit (lib)
    attrValues
    filter
    optional
    ;

  availableFeatures = builtins.attrNames config.ray.features;

  featureByName =
    name:
    config.ray.features.${name}
      or (throw "Unknown feature '${name}'. Available features: ${lib.concatStringsSep ", " availableFeatures}");

  selectFeatures = host: map featureByName host.features;

  modulesFor =
    kind: features: map (feature: feature.${kind}) (filter (feature: feature.${kind} != null) features);

  moduleAttrsFor =
    kind:
    builtins.listToAttrs (
      map (feature: {
        inherit (feature) name;
        value = feature.${kind};
      }) (filter (feature: feature.${kind} != null) (attrValues config.ray.features))
    );

  mkFirefoxPwaInstall = import ../../lib/mk-firefox-pwa-install.nix;

  specialArgsFor = host: {
    inherit
      inputs
      mkFirefoxPwaInstall
      self
      host
      ;
    flake = self;
    registry = config.ray.registry;
    inherit (host)
      hostname
      homeStateVersion
      stateVersion
      system
      type
      username
      ;
  };

  homeManagerModule = host: homeModules: {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = specialArgsFor host;
      users.${host.username} =
        { config, ... }:
        {
          _module.args.mkDotfilesSymlink =
            name: config.lib.file.mkOutOfStoreSymlink "/home/${host.username}/nix-config/dotfiles/${name}";

          imports = homeModules;
        };
      backupFileExtension = "home-manager.backup";
    };
  };

  mkNixosHost =
    host:
    let
      features = selectFeatures host;
      nixosModules = modulesFor "nixos" features;
      homeModules = modulesFor "home" features;
    in
    inputs.nixpkgs.lib.nixosSystem {
      inherit (host) system;
      specialArgs = specialArgsFor host;
      modules =
        nixosModules
        ++ optional (host.hardware != null) host.hardware
        ++ optional (homeModules != [ ]) inputs.home-manager.nixosModules.home-manager
        ++ optional (homeModules != [ ]) (homeManagerModule host homeModules);
    };
in
{
  config.ray.lib = {
    inherit
      mkNixosHost
      moduleAttrsFor
      modulesFor
      selectFeatures
      ;
  };
}
