{
  config,
  inputs,
  lib,
  ...
}:

let
  inherit (lib) filter;

  availableFeatures = builtins.attrNames config.ray.features;

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
        in
        map (required: "${name} requires ${required}") (
          filter (required: !lib.elem required host.features) feature.requires
        )
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
    user = config.ray.registry.users.${host.username};
    inherit (host)
      hostname
      homeStateVersion
      stateVersion
      system
      username
      ;
  };

  mkNixosHost =
    host:
    let
      features = selectFeatures host;
    in
    inputs.nixpkgs.lib.nixosSystem {
      inherit (host) system;
      specialArgs = specialArgsFor host;
      modules = modulesFor "nixos" features ++ host.modules;
    };

  mkHomeHost =
    host:
    let
      features = selectFeatures host;
      pkgs = import inputs.nixpkgs {
        inherit (host) system;
        config.allowUnfree = true;
        overlays = [ inputs.nur.overlays.default ];
      };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = specialArgsFor host;
      modules = modulesFor "home" features;
    };
in
{
  config.ray.lib = {
    inherit mkHomeHost mkNixosHost;
  };
}
