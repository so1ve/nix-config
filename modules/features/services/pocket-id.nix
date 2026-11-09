{ lib, ... }:

{
  ray.features."services/pocket-id" = {
    requires.allOf = [
      "security/agenix"
      "virtualisation/podman"
      "services/cloudflared"
    ];

    options = {
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start Pocket ID automatically.";
      };

      publicUrl = lib.mkOption {
        type = lib.types.str;
        description = "Public base URL of the Pocket ID instance.";
      };
    };

    nixos =
      { settings, ... }:
      { config, ... }:
      let
        inherit (config.virtualisation.quadlet) containers networks;
      in
      {
        age.secrets.pocket-id-env = {
          owner = "1000";
          group = "1000";
          mode = "0400";
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/pocket-id 0700 1000 1000 - -"
        ];

        virtualisation.quadlet.containers.pocket-id = {
          inherit (settings) autoStart;
          unitConfig = {
            Requires = containers.cloudflared.ref;
            After = containers.cloudflared.ref;
          };
          serviceConfig = {
            Restart = "always";
            TimeoutStartSec = "5min";
          };
          containerConfig = {
            ContainerName = "pocket-id";
            Image = "docker.io/pocketid/pocket-id:latest";
            User = "1000:1000";
            Network = [ networks.cloudflared.ref ];
            NetworkAlias = [ "pocket-id" ];
            NoNewPrivileges = true;
            DropCapability = [ "ALL" ];
            ReadOnly = true;
            Volume = [ "/var/lib/pocket-id:/app/data" ];
            Environment = {
              APP_URL = settings.publicUrl;
              TRUST_PROXY = "true";
              ALLOW_USER_SIGNUPS = "withToken";
              UI_CONFIG_DISABLED = "true";
            };
            EnvironmentFile = [ config.age.secrets.pocket-id-env.path ];
          };
        };

        systemd.services.pocket-id.restartTriggers = [ config.age.secrets.pocket-id-env.file ];
      };
  };
}
