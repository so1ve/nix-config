{ images, lib, ... }:

{
  ray.features."services/matrix" = {
    requires.allOf = [
      "security/agenix"
      "virtualisation/podman"
      "services/cloudflared"
      "services/pocket-id"
    ];

    options.autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Tuwunel, the Telegram bridge and its database automatically.";
    };

    nixos =
      { settings, ... }:
      {
        config,
        featureEnabled,
        pkgs,
        ...
      }:
      let
        inherit (config.virtualisation.quadlet) containers networks;
        dependencies = [
          containers.tuwunel.ref
          containers.mautrix-postgres.ref
        ];
        mautrixCheck = lib.getExe (
          pkgs.writeShellApplication {
            name = "uptarn-check-mautrix";
            runtimeInputs = [
              pkgs.bind.host
              pkgs.curl
              pkgs.gawk
              pkgs.iproute2
              pkgs.systemd
            ];
            text = ''
              if ! systemctl is-active --quiet ${lib.escapeShellArg "${containers.mautrix.serviceName}.service"}; then
                echo "mautrix service inactive"
                exit 1
              fi

              if ! systemctl is-active --quiet ${lib.escapeShellArg "${containers.mautrix-postgres.serviceName}.service"}; then
                echo "mautrix-postgres service inactive"
                exit 1
              fi

              dns=$(ip -4 -o addr show dev br-matrix-app 2>/dev/null | awk '{sub(/\/.*/, "", $4); print $4; exit}' || true)
              if [ -z "$dns" ]; then
                echo "br-matrix-app down"
                exit 1
              fi

              mautrix_ip=$(host -W 1 -t A mautrix "$dns" 2>/dev/null | awk '/ has address /{print $4; exit}' || true)
              if [ -z "$mautrix_ip" ]; then
                echo "mautrix DNS unresolved"
                exit 1
              fi

              code=$(curl -sS --max-time 2 -o /dev/null -w '%{http_code}' "http://$mautrix_ip:29317/_matrix/mau/ready" 2>/dev/null || true)
              if [ "$code" != "200" ]; then
                echo "mautrix not ready (HTTP ''${code:-000})"
                exit 1
              fi

              echo "ready"
            '';
          }
        );
      in
      {
        systemd.tmpfiles.rules = [
          "d /var/lib/matrix 0700 root root - -"
          "d /var/lib/matrix/tuwunel 0700 root root - -"
          # Match the bridge image's UID/GID so later activations preserve its access.
          "d /var/lib/matrix/mautrix 0700 1337 1337 - -"
          "d /var/lib/matrix/postgres 0755 root root - -"
        ];

        networking.firewall.interfaces = lib.genAttrs [ "br-matrix" "br-matrix-app" ] (_: {
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        });

        virtualisation.quadlet = {
          networks = {
            matrix-app.networkConfig = {
              InterfaceName = "br-matrix-app";
              Options = [ "isolate=true" ];
            };
            matrix.networkConfig = {
              InterfaceName = "br-matrix";
              Options = [
                "isolate=true"
                "no_default_route=true"
              ];
            };
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
                Image = images.tuwunel;
                Network = [ networks.matrix-app.ref ];
                PublishPort = [ "127.0.0.1:8008:8008" ];
                NoNewPrivileges = true;
                DropCapability = [ "ALL" ];
                StopTimeout = 1800;
                Volume = [
                  "/var/lib/matrix/tuwunel:/var/lib/tuwunel"
                  "${config.age.secrets.tuwunel-config.path}:/etc/tuwunel.toml:ro"
                  "${config.age.secrets.tuwunel-oidc-client-secret.path}:/run/secrets/tuwunel-oidc-client-secret:ro"
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
                Image = images.mautrix-telegram;
                Network = [
                  networks.matrix-app.ref
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
                Image = images.postgres;
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
          tuwunel.restartTriggers = [
            config.age.secrets.tuwunel-config.file
            config.age.secrets.tuwunel-oidc-client-secret.file
          ];
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
      }
      // lib.optionalAttrs (featureEnabled "services/uptarn-agent" && settings.autoStart) {
        ray.uptarn.monitors = [
          {
            key = "mautrix";
            name = "Mautrix Telegram";
            type = "exec";
            target = "mautrix + postgres";
            command = [ mautrixCheck ];
          }
        ];
      };
  };
}
