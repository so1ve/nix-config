{ images, lib, ... }:

{
  ray.features."services/hermes" = {
    requires.allOf = [
      "security/agenix"
      "virtualisation/podman"
    ];

    options = {
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start Hermes and its dedicated NapCat bridge automatically.";
      };

      account = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Dedicated QQ account for quick login, or null to log in through NapCat's WebUI.";
      };

      settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Hermes config.yaml settings.";
      };

      soul = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Shared personality for Telegram and QQ.";
      };

      personal = {
        enable = lib.mkEnableOption "BIT campus, read-only mail and Lexue tools";

        config = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Non-secret personal tool configuration.";
        };

        backupDirectory = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Host directory for encrypted native Hermes backups.";
        };

        backupRecipient = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Age recipient used to encrypt native Hermes backups.";
        };
      };

      napcat = {
        webPort = lib.mkOption {
          type = lib.types.port;
          description = "Host port for NapCat's web interface.";
        };
      };
    };

    nixos =
      { settings, ... }:
      {
        config,
        inputs,
        pkgs,
        ...
      }:
      let
        inherit (config.virtualisation.quadlet) containers networks volumes;
        personalEnvironment = "/opt/data/.local/share/hermes-personal";
        hermesConfig = (pkgs.formats.yaml { }).generate "hermes-config.yaml" (
          lib.recursiveUpdate (lib.optionalAttrs settings.personal.enable {
            mcp_servers.personal = {
              command = "${personalEnvironment}/bin/hermes-personal-mcp";
              timeout = 300;
            };
          }) settings.settings
        );
        soul = pkgs.writeText "hermes-soul.md" settings.soul;
        start = pkgs.writeText "hermes-start.sh" ''
          set -eu

          uv=$(find /opt/hermes/tools -path '*/uv' -type f | head -n 1)
          export PATH="$(dirname "$uv"):$PATH"

          plugin="$HERMES_HOME/plugins/onebot-platform"
          if [ ! -d "$plugin/.git" ] || [ "$(git -C "$plugin" rev-parse HEAD)" != "${inputs.hermes-onebot.rev}" ]; then
            hermes plugins install --force --enable --yes-deps \
              --ref ${inputs.hermes-onebot.rev} \
              https://github.com/mario841859784/hermes-plugin-onebot.git
          fi

          ${lib.optionalString settings.personal.enable ''
            sh /etc/hermes/personal-start.sh "$uv"
          ''}

          exec hermes gateway run
        '';
      in
      {
        imports = [
          (import ./hermes/_personal.nix {
            inherit (settings) personal;
            inherit personalEnvironment;
          })
        ];
        networking.firewall.interfaces.br-hermes = {
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };

        virtualisation.quadlet = {
          networks.hermes.networkConfig = {
            InterfaceName = "br-hermes";
            Options = [ "isolate=true" ];
          };

          volumes = {
            # Keep data under Podman's existing "hermes" volume instead of systemd-hermes.
            hermes.volumeConfig.VolumeName = "hermes";
            hermes-napcat-qq = { };
            hermes-napcat-config = { };
          };

          containers = {
            hermes = {
              inherit (settings) autoStart;
              unitConfig = {
                Wants = [ containers.hermes-napcat.ref ];
                After = [ containers.hermes-napcat.ref ];
              };
              serviceConfig = {
                Restart = "always";
                TimeoutStartSec = "10min";
              };
              containerConfig = {
                Image = images.hermes;
                Network = [ networks.hermes.ref ];
                Volume = [
                  "${volumes.hermes.ref}:/opt/data"
                  "${hermesConfig}:/etc/hermes/config.yaml:ro"
                  "${start}:/etc/hermes/start.sh:ro"
                ]
                ++ lib.optional (settings.soul != "") "${soul}:/opt/data/SOUL.md:ro";
                Environment.TZ = config.time.timeZone;
                EnvironmentFile = [ config.age.secrets.hermes-env.path ];
                NoNewPrivileges = true;
                Exec = "sh /etc/hermes/start.sh";
              };
            };

            hermes-napcat = {
              inherit (settings) autoStart;
              serviceConfig.Restart = "always";
              containerConfig = {
                Image = images.napcat;
                Network = [ networks.hermes.ref ];
                NetworkAlias = [ "napcat" ];
                PublishPort = [ "${toString settings.napcat.webPort}:6099" ];
                Volume = [
                  "${volumes.hermes-napcat-qq.ref}:/app/.config/QQ"
                  "${volumes.hermes-napcat-config.ref}:/app/napcat/config"
                  "${config.age.secrets.hermes-napcat-config.path}:/app/templates/ws.json:ro"
                ];
                Environment = {
                  NAPCAT_UID = "1000";
                  NAPCAT_GID = "1000";
                  MODE = "ws";
                  TZ = config.time.timeZone;
                }
                // lib.optionalAttrs (settings.account != null) {
                  NAPCAT_QUICK_ACCOUNT = settings.account;
                };
                EnvironmentFile = [ config.age.secrets.hermes-napcat-env.path ];
              };
            };
          };
        };

        systemd.services = {
          ${containers.hermes.serviceName}.restartTriggers = [
            config.age.secrets.hermes-env.file
          ];
          ${containers.hermes-napcat.serviceName}.restartTriggers = [
            config.age.secrets.hermes-napcat-env.file
            config.age.secrets.hermes-napcat-config.file
          ];
        };
      };
  };
}
