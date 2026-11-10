{ lib, ... }:

{
  ray.features."services/ddclient" = {
    requires = settings: {
      allOf = lib.optional (settings.environmentSecrets != [ ]) "security/agenix";
    };

    options = {
      settings = lib.mkOption {
        type = lib.types.attrs;
        description = "Options passed to the native NixOS ddclient module.";
      };

      environmentSecrets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Agenix environment secrets read directly by ddclient.";
      };
    };

    nixos = { settings, ... }: { config, ... }: {
      services.ddclient = settings.settings // {
        enable = true;
      };

      systemd.services.ddclient = {
        serviceConfig.EnvironmentFile = map (
          name: config.age.secrets.${name}.path
        ) settings.environmentSecrets;
        restartTriggers = map (name: config.age.secrets.${name}.file) settings.environmentSecrets;
      };
    };
  };
}
