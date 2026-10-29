{ config, lib, ... }:

let
  inherit (lib) mkOption types;

  requirementsType = types.submodule {
    options = {
      allOf = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Features that must all be enabled alongside this feature.";
      };

      anyOf = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Alternative features, at least one of which must be enabled.";
      };
    };
  };

  featureType = types.submodule {
    options = {
      options = mkOption {
        type = types.attrsOf types.raw;
        default = { };
        description = "Native option declarations for this feature's per-host settings.";
      };

      nixos = mkOption {
        type = types.nullOr (types.functionTo types.deferredModule);
        default = null;
        description = "Function from this feature's settings to a NixOS module.";
      };

      home = mkOption {
        type = types.nullOr (types.functionTo types.deferredModule);
        default = null;
        description = "Function from this feature's settings to a Home Manager module.";
      };

      requires = mkOption {
        type = types.coercedTo (types.attrsOf types.raw) (requirements: _: requirements) (
          types.functionTo requirementsType
        );
        default = { };
        description = "Feature dependencies, either fixed or computed from this feature's settings.";
      };
    };
  };

  nixosHostType = types.submodule (
    { name, ... }:
    {
      options = {
        hostname = mkOption {
          type = types.str;
          default = name;
        };

        isServer = mkOption {
          type = types.bool;
          default = false;
          description = "Identify this host as a server";
        };

        system = mkOption {
          type = types.enum [ "x86_64-linux" ];
          default = "x86_64-linux";
        };

        username = mkOption {
          type = types.str;
        };

        stateVersion = mkOption {
          type = types.str;
        };

        homeStateVersion = mkOption {
          type = types.str;
        };

        features = mkOption {
          type = types.submodule {
            options = lib.mapAttrs (
              name: feature:
              mkOption {
                type = types.nullOr (types.submodule { options = feature.options; });
                default = null;
                description = "Enable ${name} and configure its settings.";
              }
            ) config.ray.features;
          };
          default = { };
          apply = lib.filterAttrs (_: settings: settings != null);
          description = "Enabled features and their typed settings. An empty set uses defaults.";
        };

        modules = mkOption {
          type = types.listOf types.raw;
          default = [ ];
          description = "Host-specific NixOS modules.";
        };
      };
    }
  );

  userType = types.submodule {
    options = {
      description = mkOption {
        type = types.str;
      };

      gitName = mkOption {
        type = types.str;
      };

      gitEmail = mkOption {
        type = types.str;
      };
    };
  };

in
{
  options.ray = {
    features = mkOption {
      type = types.attrsOf featureType;
      default = { };
      description = "Automatically discovered composable features.";
    };

    hosts.nixos = mkOption {
      type = types.attrsOf nixosHostType;
      default = { };
      description = "NixOS host registry.";
    };

    registry = {
      users = mkOption {
        type = types.attrsOf userType;
        default = { };
      };

      nixCacheSettings = mkOption {
        type = types.submodule {
          options = {
            extra-substituters = mkOption {
              type = types.listOf types.str;
              default = [ ];
            };

            extra-trusted-public-keys = mkOption {
              type = types.listOf types.str;
              default = [ ];
            };
          };
        };
        default = { };
      };
    };

    lib = mkOption {
      type = types.attrsOf types.raw;
      default = { };
      description = "Helpers derived from the feature and host registries.";
    };
  };
}
