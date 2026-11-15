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
        personalPackage = pkgs.callPackage ../../../packages/hermes-tools { };
        # Give uv a new wheel path when the package changes without a version bump.
        personalBundle = "/etc/hermes/${baseNameOf personalPackage.outPath}";
        personalEnvironment = "/opt/data/.local/share/hermes-personal";
        cronJob = id: name: expr: monitor: prompt: {
          inherit id name prompt;
          schedule = {
            kind = "cron";
            inherit expr;
            display = expr;
          };
          timezone = "Asia/Shanghai";
          deliver = "local";
          failure_deliver = "local";
          workdir = "/opt/data";
          skills = [ "personal-assistant" ];
          monitor_script = "personal/${monitor}";
          interpreter = "${personalEnvironment}/bin/python";
          continuity = true;
          catch_up = false;
          enabled = true;
          state = "scheduled";
          repeat = {
            times = null;
            completed = 0;
          };
        };
        personalCron = pkgs.writeText "hermes-personal-cron.json" (
          builtins.toJSON {
            jobs = [
              (cronJob "f3035e0210eb" "Hermes · 邮件" "*/10 * * * *" "mail-check.py"
                "请子 Agent 查看本次变化的邮件，找出需要 Ray 留意的事项。"
              )
              (cronJob "0af105382801" "Hermes · 乐学" "*/30 * * * *" "lexue-check.py"
                "请子 Agent 比较本次和上次的乐学日历，找出新增、变更或取消的截止事项。"
              )
            ];
          }
        );
        hermesConfig = (pkgs.formats.yaml { }).generate "hermes-config.yaml" (
          lib.recursiveUpdate (lib.optionalAttrs settings.personal.enable {
            mcp_servers.personal = {
              command = "${personalEnvironment}/bin/hermes-personal-mcp";
              timeout = 300;
            };
          }) settings.settings
        );
        yanhekit = pkgs.applyPatches {
          name = "yanhekit-hermes";
          src = inputs.yanhekit;
          patches = [ ../../../packages/hermes-tools/yanhekit-headless.patch ];
        };
        soul = pkgs.writeText "hermes-soul.md" settings.soul;
        personalConfig = pkgs.writeText "hermes-personal.json" (builtins.toJSON settings.personal.config);
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
            "$uv" venv --allow-existing --no-python-downloads --python "$(command -v python3)" ${personalEnvironment}
            (
              cd ${personalBundle}
              "$uv" pip sync --python ${personalEnvironment}/bin/python --require-hashes requirements.txt
            )

            if [ ! -e "$HERMES_HOME/cron/jobs.json" ]; then
              if ! (
                umask 077
                cd "$HERMES_HOME" &&
                mkdir -p cron &&
                seed=$(mktemp cron/.jobs.XXXXXX) &&
                trap 'rm -f "$seed"' EXIT &&
                cat /etc/hermes/personal-cron.json > "$seed" &&
                { ln -T "$seed" cron/jobs.json || [ -f cron/jobs.json ]; }
              ); then
                printf '%s\n' 'Could not initialize the personal Hermes cron jobs.' >&2
              fi
            fi
          ''}

          exec hermes gateway run
        '';
      in
      {
        assertions = [
          {
            assertion =
              !settings.personal.enable
              || settings.personal.backupDirectory == null
              || settings.personal.backupRecipient != null;
            message = "Hermes backups need personal.backupRecipient because the profile contains credentials.";
          }
        ];
        networking.firewall.interfaces.br-hermes = {
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };

        virtualisation.quadlet = {
          networks.hermes.networkConfig = {
            NetworkName = "hermes";
            InterfaceName = "br-hermes";
            Options = [ "isolate=true" ];
          };

          volumes = {
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
                ++ lib.optional (settings.soul != "") "${soul}:/opt/data/SOUL.md:ro"
                ++ lib.optionals settings.personal.enable [
                  "${personalPackage}:${personalBundle}:ro"
                  "${personalConfig}:/etc/hermes/personal.json:ro"
                  "${personalCron}:/etc/hermes/personal-cron.json:ro"
                  "${personalPackage}/skills/personal-assistant:/opt/data/skills/personal-assistant:ro"
                  "${personalPackage}/scripts:/opt/data/scripts/personal:ro"
                  "${personalPackage}/hooks/proactive-chat:/opt/data/hooks/proactive-chat:ro"
                  "${config.age.secrets.hermes-campus.path}:/run/hermes/campus.json:ro"
                ]
                ++ lib.optionals settings.personal.enable (
                  map (name: "${yanhekit}/skills/${name}:/opt/data/skills/${name}:ro") (
                    builtins.attrNames (builtins.readDir "${inputs.yanhekit}/skills")
                  )
                );
                Environment = {
                  TZ = config.time.timeZone;
                }
                // lib.optionalAttrs settings.personal.enable {
                  HERMES_PERSONAL_CONFIG = "/etc/hermes/personal.json";
                  BIT_CREDENTIALS = "/run/hermes/campus.json";
                };
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
          ]
          ++ lib.optional settings.personal.enable config.age.secrets.hermes-campus.file;
          ${containers.hermes-napcat.serviceName}.restartTriggers = [
            config.age.secrets.hermes-napcat-env.file
            config.age.secrets.hermes-napcat-config.file
          ];
        }
        // lib.optionalAttrs (settings.personal.enable && settings.personal.backupDirectory != null) {
          hermes-backup = {
            description = "Encrypt a native Hermes backup";
            requires = [ "${containers.hermes.serviceName}.service" ];
            after = [ "${containers.hermes.serviceName}.service" ];
            unitConfig.RequiresMountsFor = [ settings.personal.backupDirectory ];
            serviceConfig = {
              Type = "oneshot";
              UMask = "0077";
            };
            path = [
              pkgs.podman
              pkgs.coreutils
              pkgs.age
            ];
            script = ''
              set -euo pipefail
              podman exec --user 10000:10000 systemd-hermes \
                mkdir -p /opt/data/backups
              podman exec --user 10000:10000 systemd-hermes \
                hermes backup --keep 7 --output /opt/data/backups/hermes.zip
              backup_dir=${lib.escapeShellArg settings.personal.backupDirectory}
              mkdir -p "$backup_dir"
              target="$backup_dir/hermes-$(date +%F-%H%M%S).zip.age"
              podman exec --user 10000:10000 systemd-hermes \
                cat /opt/data/backups/hermes.zip \
                | age --recipient ${lib.escapeShellArg settings.personal.backupRecipient} --output "$target.part"
              chmod 600 "$target.part"
              mv "$target.part" "$target"
            '';
          };
        };

        systemd.timers.hermes-backup =
          lib.mkIf (settings.personal.enable && settings.personal.backupDirectory != null)
            {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = "*-*-* 03:30:00 Asia/Shanghai";
                Persistent = true;
              };
            };
      };
  };
}
