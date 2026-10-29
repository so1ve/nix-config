{ lib, ... }:

{
  ray.features."services/matrix" = {
    requires.allOf = [
      "security/agenix"
      "virtualisation/podman"
      "services/cloudflared"
    ];

    options.autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Tuwunel, the Telegram bridge and its database automatically.";
    };

    nixos =
      settings:
      {
        config,
        pkgs,
        ...
      }:
      let
        inherit (config.virtualisation.quadlet) containers networks;
        dependencies = [
          containers.tuwunel.ref
          containers.mautrix-postgres.ref
        ];
      in
      {
        systemd.tmpfiles.rules = [
          "d /var/lib/matrix 0700 root root - -"
          "d /var/lib/matrix/tuwunel 0700 root root - -"
          # Match the bridge image's UID/GID so later activations preserve its access.
          "d /var/lib/matrix/mautrix 0700 1337 1337 - -"
          "d /var/lib/matrix/postgres 0755 root root - -"
        ];

        networking.firewall.interfaces.br-matrix = {
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };

        virtualisation.quadlet = {
          networks.matrix.networkConfig = {
            NetworkName = "matrix";
            InterfaceName = "br-matrix";
            Options = [
              "isolate=true"
              "no_default_route=1"
            ];
          };

          containers = {
            tuwunel = {
              inherit (settings) autoStart;
              serviceConfig = {
                Restart = "always";
                TimeoutStartSec = "5min";
                # Database upgrades must reach a safe stopping point before SIGKILL.
                TimeoutStopSec = "1830s";
              };
              containerConfig = {
                ContainerName = "tuwunel";
                Image = "docker.io/jevolk/tuwunel:latest";
                Network = [ networks.cloudflared.ref ];
                NoNewPrivileges = true;
                DropCapability = [ "ALL" ];
                StopTimeout = 1800;
                Volume = [
                  "/var/lib/matrix/tuwunel:/var/lib/tuwunel"
                  "${config.age.secrets.tuwunel-config.path}:/etc/tuwunel.toml:ro"
                ];
                Environment.TUWUNEL_CONFIG = "/etc/tuwunel.toml";
              };
            };

            mautrix = {
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
                # The restored homeserver's appservice registration uses this name.
                ContainerName = "mautrix";
                Image = "dock.mau.dev/mautrix/telegram:v26.10";
                Network = [
                  networks.cloudflared.ref
                  networks.matrix.ref
                ];
                NoNewPrivileges = true;
                Volume = [ "/var/lib/matrix/mautrix:/data" ];
              };
            };

            mautrix-postgres = {
              inherit (settings) autoStart;
              serviceConfig = {
                Restart = "always";
                TimeoutStartSec = "5min";
              };
              containerConfig = {
                ContainerName = "mautrix-postgres";
                Image = "docker.io/library/postgres:latest";
                Network = [ networks.matrix.ref ];
                NoNewPrivileges = true;
                Volume = [ "/var/lib/matrix/postgres:/var/lib/postgresql" ];
                Environment = {
                  POSTGRES_USER = "mautrix";
                  POSTGRES_DB = "mautrix";
                };
                EnvironmentFile = [ config.age.secrets.mautrix-postgres-env.path ];
                Notify = "healthy";
                HealthCmd = "pg_isready -h 127.0.0.1 -U mautrix -d mautrix";
              };
            };
          };
        };

        systemd.services = {
          tuwunel.restartTriggers = [ config.age.secrets.tuwunel-config.file ];
          mautrix = {
            # The image changes ownership and upgrades these files, so it needs writable copies.
            preStart = ''
              ${pkgs.coreutils}/bin/install -o 1337 -g 1337 -m 0600 ${config.age.secrets.mautrix-config.path} /var/lib/matrix/mautrix/config.yaml
              ${pkgs.coreutils}/bin/install -o 1337 -g 1337 -m 0600 ${config.age.secrets.mautrix-registration.path} /var/lib/matrix/mautrix/registration.yaml
            '';
            restartTriggers = [
              config.age.secrets.mautrix-config.file
              config.age.secrets.mautrix-registration.file
            ];
          };
          mautrix-postgres.restartTriggers = [ config.age.secrets.mautrix-postgres-env.file ];
        };
      };
  };
}
