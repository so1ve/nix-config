{ lib, ... }:

{
  ray.features."services/authelia" = {
    requires.allOf = [
      "security/agenix"
      "virtualisation/podman"
      "services/cloudflared"
    ];

    options = {
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start Authelia automatically.";
      };
    };

    nixos =
      settings:
      { config, ... }:
      let
        inherit (config.virtualisation.quadlet) containers networks;
      in
      {
        age.secrets = {
          authelia-config = {
            owner = "1000";
            group = "1000";
            mode = "0400";
          };
          authelia-users = {
            owner = "1000";
            group = "1000";
            mode = "0400";
          };
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/authelia 0700 1000 1000 - -"
        ];

        virtualisation.quadlet.containers.authelia = {
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
            ContainerName = "authelia";
            Image = "docker.io/authelia/authelia:latest";
            User = "1000:1000";
            Network = [ networks.cloudflared.ref ];
            NetworkAlias = [ "authelia" ];
            NoNewPrivileges = true;
            DropCapability = [ "ALL" ];
            Volume = [
              "/var/lib/authelia:/data"
              "${config.age.secrets.authelia-config.path}:/config/configuration.yml:ro"
              "${config.age.secrets.authelia-users.path}:/config/users_database.yml:ro"
            ];
          };
        };

        systemd.services.authelia.restartTriggers = [
          config.age.secrets.authelia-config.file
          config.age.secrets.authelia-users.file
        ];
      };
  };
}
