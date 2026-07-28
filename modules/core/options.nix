{ lib, ... }:

let
  inherit (lib) mkOption types;

  featureType = types.submodule {
    options = {
      nixos = mkOption {
        type = types.nullOr types.deferredModule;
        default = null;
        description = "Optional NixOS module provided by this feature.";
      };

      home = mkOption {
        type = types.nullOr types.deferredModule;
        default = null;
        description = "Optional Home Manager module provided by this feature.";
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
          type = types.listOf types.str;
          default = [ ];
        };

        hardware = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Optional host hardware module.";
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

      extraGroups = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
    };
  };

  binaryCacheType = types.submodule {
    options = {
      url = mkOption {
        type = types.str;
      };

      publicKey = mkOption {
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

      binaryCaches = mkOption {
        type = types.attrsOf binaryCacheType;
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
