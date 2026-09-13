{
  features,
  lib,
}:

let
  inherit (lib) filter optional;

  availableFeatures = builtins.attrNames features;
  featureExists = name: builtins.hasAttr name features;
  unknownFeature =
    name: "Unknown feature '${name}'. Available features: ${lib.concatStringsSep ", " availableFeatures}";

  featureByName =
    name:
    features.${name} or (throw (unknownFeature name));

  select =
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
in
{
  enabled =
    enabledFeatures: name:
    if featureExists name then
      lib.elem name enabledFeatures
    else
      throw (unknownFeature name);

  inherit select;
}
