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
      missingRequirements = lib.concatMap (
        name:
        let
          feature = featureByName name;
          requirements = feature.requires host.features.${name};
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
      ) enabledFeatures;
    in
    if missingRequirements == [ ] then
      lib.genAttrs enabledFeatures featureByName
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
