{
  config,
  inputs,
  lib,
  ...
}:

let
  inherit (lib)
    filter
    optional
    ;

  availableFeatures = builtins.attrNames config.ray.features;
  featureExists = name: builtins.hasAttr name config.ray.features;

  featureByName =
    name:
    config.ray.features.${name}
      or (throw "Unknown feature '${name}'. Available features: ${lib.concatStringsSep ", " availableFeatures}");

  selectFeatures =
    host:
    let
      missingRequirements = lib.concatMap (
        name:
        let
          feature = featureByName name;
          requirements = feature.requires.allOf ++ feature.requires.anyOf;
          unknownRequirements = filter (required: !featureExists required) requirements;
          missingAll = filter (
            required: featureExists required && !lib.elem required host.features
          ) feature.requires.allOf;
          missingAny =
            feature.requires.anyOf != [ ]
            && !lib.any (required: lib.elem required host.features) feature.requires.anyOf;
        in
        map (required: "${name} references unknown feature ${required}") unknownRequirements
        ++ map (required: "${name} requires ${required}") missingAll
        ++ optional missingAny "${name} requires any of: ${lib.concatStringsSep ", " feature.requires.anyOf}"
      ) host.features;
    in
    if missingRequirements == [ ] then
      map featureByName host.features
    else
      throw ''
        Missing feature dependencies for host '${host.hostname}':
        ${lib.concatMapStringsSep "\n" (dependency: "  - ${dependency}") missingRequirements}
      '';

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
    featureEnabled =
      name:
      if featureExists name then
        lib.elem name host.features
      else
        throw "Unknown feature '${name}'. Available features: ${lib.concatStringsSep ", " availableFeatures}";
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
    inherit mkNixosHost;
  };
}
