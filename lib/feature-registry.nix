{
  features,
  lib,
}:

let
  inherit (lib) filter optional;

  availableFeatures = builtins.attrNames features;
  featureExists = name: builtins.hasAttr name features;
  unknownFeature =
    name:
    "Unknown feature '${name}'. Available features: ${lib.concatStringsSep ", " availableFeatures}";

  featureByName = name: features.${name} or (throw (unknownFeature name));

  select =
    host:
    let
      enabledFeatures = builtins.attrNames host.features;
      instances = lib.concatMap (
        featureName:
        let
          feature = featureByName featureName;
          settings = host.features.${featureName};
          namedSettings =
            if feature.multiple then settings else { ${builtins.baseNameOf featureName} = settings; };
        in
        lib.mapAttrsToList (name: settings: {
          inherit
            featureName
            feature
            name
            settings
            ;
        }) namedSettings
      ) enabledFeatures;
      missingRequirements = lib.concatMap (
        instance:
        let
          name = instance.featureName + lib.optionalString instance.feature.multiple " (${instance.name})";
          requirements = instance.feature.requires instance.settings;
          unknownRequirements = filter (required: !featureExists required) (
            requirements.allOf ++ requirements.anyOf
          );
          missingAll = filter (
            required: featureExists required && !builtins.hasAttr required host.features
          ) requirements.allOf;
          missingAny =
            requirements.anyOf != [ ]
            && !lib.any (required: builtins.hasAttr required host.features) requirements.anyOf;
        in
        map (required: "${name} references unknown feature ${required}") unknownRequirements
        ++ map (required: "${name} requires ${required}") missingAll
        ++ optional missingAny "${name} requires any of: ${lib.concatStringsSep ", " requirements.anyOf}"
      ) instances;
    in
    if missingRequirements == [ ] then
      instances
    else
      throw ''
        Missing feature dependencies for host '${host.hostname}':
        ${lib.concatMapStringsSep "\n" (dependency: "  - ${dependency}") missingRequirements}
      '';
in
{
  enabled =
    enabledFeatures: name:
    if featureExists name then builtins.hasAttr name enabledFeatures else throw (unknownFeature name);

  inherit select;
}
