{ lib, ... }:

{
  ray.features."services/new-api" = {
    requires.allOf = [
      "security/agenix"
      "virtualisation/podman"
      "services/cloudflared"
    ];

    options.autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start New API and its database and cache automatically.";
    };

    nixos =
      settings:
      { config, hostname, ... }:
      let
        inherit (config.virtualisation.quadlet) containers networks;
        secretsDir = ../../../secrets + "/${hostname}";
        dependencies = [
          containers.new-api-postgres.ref
          containers.new-api-redis.ref
        ];
      in
      {
        age.secrets = {
          new-api-env.file = secretsDir + "/new-api-env.age";
          new-api-postgres-env.file = secretsDir + "/new-api-postgres-env.age";
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/new-api 0700 root root - -"
          "d /var/lib/new-api/data 0700 root root - -"
          "d /var/lib/new-api/logs 0700 root root - -"
          # PostgreSQL traverses this mount; the image creates its private data directory inside.
          "d /var/lib/new-api/postgres 0755 root root - -"
        ];

        networking.firewall.interfaces.br-new-api = {
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };

        virtualisation.quadlet = {
          networks.new-api.networkConfig = {
            NetworkName = "new-api";
            InterfaceName = "br-new-api";
            Options = [
              "isolate=true"
              "no_default_route=1"
            ];
          };

          containers = {
            new-api = {
              inherit (settings) autoStart;
              unitConfig = {
                Requires = dependencies;
                After = dependencies;
              };
              serviceConfig = {
                Restart = "always";
                TimeoutStartSec = "5min";
              };
              containerConfig = {
                ContainerName = "new-api";
                Image = "docker.io/calciumion/new-api:latest";
                Network = [
                  networks.cloudflared.ref
                  networks.new-api.ref
                ];
                NoNewPrivileges = true;
                DropCapability = [ "ALL" ];
                Volume = [
                  "/var/lib/new-api/data:/data"
                  "/var/lib/new-api/logs:/app/logs"
                ];
                Environment = {
                  TZ = "Asia/Shanghai";
                  ERROR_LOG_ENABLED = "true";
                  BATCH_UPDATE_ENABLED = "true";
                };
                EnvironmentFile = [ config.age.secrets.new-api-env.path ];
                Exec = "--log-dir /app/logs";
              };
            };

            new-api-postgres = {
              inherit (settings) autoStart;
              serviceConfig = {
                Restart = "always";
                TimeoutStartSec = "5min";
              };
              containerConfig = {
                ContainerName = "new-api-postgres";
                Image = "docker.io/library/postgres:latest";
                Network = [ networks.new-api.ref ];
                NetworkAlias = [ "postgres" ];
                NoNewPrivileges = true;
                Volume = [ "/var/lib/new-api/postgres:/var/lib/postgresql" ];
                Environment = {
                  POSTGRES_USER = "root";
                  POSTGRES_DB = "new-api";
                };
                EnvironmentFile = [ config.age.secrets.new-api-postgres-env.path ];
                Notify = "healthy";
                HealthCmd = "pg_isready -h 127.0.0.1 -U root -d new-api";
              };
            };

            new-api-redis = {
              inherit (settings) autoStart;
              serviceConfig = {
                Restart = "always";
                TimeoutStartSec = "5min";
              };
              containerConfig = {
                ContainerName = "new-api-redis";
                Image = "docker.io/library/redis:latest";
                Network = [ networks.new-api.ref ];
                NetworkAlias = [ "redis" ];
                NoNewPrivileges = true;
                Notify = "healthy";
                HealthCmd = "redis-cli ping";
              };
            };
          };
        };

        systemd.services = {
          new-api.restartTriggers = [ config.age.secrets.new-api-env.file ];
          new-api-postgres.restartTriggers = [ config.age.secrets.new-api-postgres-env.file ];
        };
      };
  };
}
