{ lib }:

let
  evaluate =
    selections:
    let
      config =
        (lib.evalModules {
          modules = [
            ../modules/core/options.nix
            {
              ray.features = {
                "helpers/base".options.label = lib.mkOption {
                  type = lib.types.str;
                  default = "base";
                };
                "helpers/fallback" = { };
                application = {
                  multiple = true;
                  options = { name, ... }: {
                    dataDir = lib.mkOption {
                      type = lib.types.str;
                      default = "/state/${name}";
                    };
                    needsBase = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                    };
                    needsAlternative = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                    };
                  };
                  requires = settings: {
                    allOf = lib.optional settings.needsBase "helpers/base";
                    anyOf = lib.optionals settings.needsAlternative [
                      "helpers/base"
                      "helpers/fallback"
                    ];
                  };
                  nixos = { name, settings }: { outputs.${name} = "nixos:${settings.dataDir}"; };
                  home = { name, settings }: { outputs.${name} = "home:${settings.dataDir}"; };
                };
              };
              ray.hosts.nixos.test = {
                username = "ray";
                stateVersion = "26.05";
                homeStateVersion = "26.05";
                features = selections;
              };
            }
          ];
        }).config;
      registry = import ../lib/feature-registry.nix {
        inherit lib;
        features = config.ray.features;
      };
      host = config.ray.hosts.nixos.test;
    in
    {
      inherit registry host;
      instances = registry.select host;
    };

  pair = evaluate {
    application = {
      first = { };
      second.dataDir = "/custom";
    };
  };
  render =
    kind:
    (lib.evalModules {
      modules = [
        { options.outputs = lib.mkOption { type = lib.types.attrsOf lib.types.str; }; }
      ]
      ++ map (instance: instance.feature.${kind} { inherit (instance) name settings; }) pair.instances;
    }).config.outputs;
  succeeds = value: (builtins.tryEval (builtins.deepSeq value true)).success;
in
lib.runTests {
  testSingleFeature = {
    expr =
      map (instance: { inherit (instance) name settings; })
        (evaluate { "helpers/base" = { }; }).instances;
    expected = [
      {
        name = "base";
        settings.label = "base";
      }
    ];
  };
  testNixosInstances = {
    expr = render "nixos";
    expected = {
      first = "nixos:/state/first";
      second = "nixos:/custom";
    };
  };
  testHomeInstances = {
    expr = render "home";
    expected = {
      first = "home:/state/first";
      second = "home:/custom";
    };
  };
  testEmptyInstancesAreDisabled = {
    expr =
      let
        result = evaluate { application = { }; };
      in
      {
        enabled = result.registry.enabled result.host.features "application";
        count = builtins.length result.instances;
      };
    expected = {
      enabled = false;
      count = 0;
    };
  };
  testEveryInstanceChecksAllDependencies = {
    expr =
      succeeds
        (evaluate {
          application.first = { };
          application.second.needsBase = true;
        }).instances;
    expected = false;
  };
  testEveryInstanceChecksAlternativeDependencies = {
    expr =
      succeeds
        (evaluate {
          application.first = { };
          application.second.needsAlternative = true;
        }).instances;
    expected = false;
  };
  testDependenciesCanBeSatisfied = {
    expr =
      succeeds
        (evaluate {
          "helpers/base" = { };
          application.first.needsBase = true;
          application.second.needsAlternative = true;
        }).instances;
    expected = true;
  };
  testInstanceSettingsAreTyped = {
    expr = succeeds (evaluate { application.bad.needsBase = "true"; }).instances;
    expected = false;
  };
}
