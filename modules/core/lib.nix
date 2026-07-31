{
  config,
  inputs,
  lib,
  ...
}:

let
  inherit (lib)
    filter
    filterAttrs
    mapAttrs
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
    mapAttrs (_: feature: feature.${kind}) (
      filterAttrs (_: feature: feature.${kind} != null) config.ray.features
    );

  mkDotfilesSymlink = import ../../lib/mk-dotfiles-symlink.nix;
  mkFocusOrLaunch = import ../../lib/mk-focus-or-launch.nix;
  mkChromiumPwa = import ../../lib/mk-chromium-pwa.nix {
    inherit lib mkFocusOrLaunch;
  };
  mkFirefoxPwaInstall = import ../../lib/mk-firefox-pwa-install.nix { inherit lib; };
  mkAppImage = import ../../lib/mk-appimage.nix { inherit lib; };

  specialArgsFor =
    host:
    let
      hasFeatureEnabled = name: lib.elem name host.features;
    in
    {
      inherit
        hasFeatureEnabled
        inputs
        mkAppImage
        mkChromiumPwa
        mkDotfilesSymlink
        mkFirefoxPwaInstall
        mkFocusOrLaunch
        ;
      mkDolphinPlace = import ../../lib/mk-dolphin-place.nix { inherit hasFeatureEnabled; };
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
        ++ host.modules
        ++ optional (homeModules != [ ]) inputs.home-manager.nixosModules.home-manager
        ++ optional (homeModules != [ ]) (homeManagerModule host homeModules);
    };
in
{
  config.ray.lib = {
    inherit
      mkNixosHost
      moduleAttrsFor
      ;
  };
}
