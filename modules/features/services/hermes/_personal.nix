{ personal, personalEnvironment }:
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.age.secrets) hermes-campus;
  inherit (config.virtualisation.quadlet.containers) hermes;
  personalPackage = pkgs.callPackage ../../../../packages/hermes-tools { };
  # Give uv a new wheel path when the package changes without a version bump.
  bundle = "/etc/hermes/${baseNameOf personalPackage.outPath}";
  toolsConfig = "/etc/hermes/personal.json";
  campusCredentials = "/run/hermes/campus.json";
  cronSeed = "/etc/hermes/personal-cron.json";

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
  cronJobs = pkgs.writeText "hermes-personal-cron.json" (
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

  yanhekit = pkgs.applyPatches {
    name = "yanhekit-hermes";
    src = inputs.yanhekit;
    patches = [ ../../../../packages/hermes-tools/yanhekit-headless.patch ];
  };
  personalConfig = pkgs.writeText "hermes-personal.json" (builtins.toJSON personal.config);
  start = pkgs.writeText "hermes-personal-start.sh" ''
    set -eu

    uv=$1
    "$uv" venv --allow-existing --no-python-downloads --python "$(command -v python3)" ${personalEnvironment}
    (
      cd ${bundle}
      "$uv" pip sync --python ${personalEnvironment}/bin/python --require-hashes requirements.txt
    )

    if [ ! -e "$HERMES_HOME/cron/jobs.json" ]; then
      if ! (
        umask 077
        cd "$HERMES_HOME" &&
        mkdir -p cron &&
        seed=$(mktemp cron/.jobs.XXXXXX) &&
        trap 'rm -f "$seed"' EXIT &&
        cat ${cronSeed} > "$seed" &&
        { ln -T "$seed" cron/jobs.json || [ -f cron/jobs.json ]; }
      ); then
        printf '%s\n' 'Could not initialize the personal Hermes cron jobs.' >&2
      fi
    fi
  '';
  backupEnabled = personal.backupDirectory != null;
in
{
  config = lib.mkIf personal.enable {
    assertions = [
      {
        assertion = !backupEnabled || personal.backupRecipient != null;
        message = "Hermes backups need personal.backupRecipient because the profile contains credentials.";
      }
    ];

    virtualisation.quadlet.containers.hermes.containerConfig = {
      Volume = lib.mkAfter (
        [
          "${start}:/etc/hermes/personal-start.sh:ro"
          "${personalPackage}:${bundle}:ro"
          "${personalConfig}:${toolsConfig}:ro"
          "${cronJobs}:${cronSeed}:ro"
          "${personalPackage}/skills/personal-assistant:/opt/data/skills/personal-assistant:ro"
          "${personalPackage}/scripts:/opt/data/scripts/personal:ro"
          "${personalPackage}/hooks/proactive-chat:/opt/data/hooks/proactive-chat:ro"
          "${hermes-campus.path}:${campusCredentials}:ro"
        ]
        ++ map (name: "${yanhekit}/skills/${name}:/opt/data/skills/${name}:ro") (
          builtins.attrNames (builtins.readDir "${inputs.yanhekit}/skills")
        )
      );
      Environment = {
        HERMES_PERSONAL_CONFIG = toolsConfig;
        BIT_CREDENTIALS = campusCredentials;
      };
    };

    systemd.services.${hermes.serviceName}.restartTriggers = lib.mkAfter [ hermes-campus.file ];

    systemd.services.hermes-backup = lib.mkIf backupEnabled {
      description = "Encrypt a native Hermes backup";
      requires = [ "${hermes.serviceName}.service" ];
      after = [ "${hermes.serviceName}.service" ];
      unitConfig.RequiresMountsFor = [ personal.backupDirectory ];
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
        podman exec --user 10000:10000 ${hermes.podmanName} \
          mkdir -p /opt/data/backups
        podman exec --user 10000:10000 ${hermes.podmanName} \
          hermes backup --keep 7 --output /opt/data/backups/hermes.zip
        backup_dir=${lib.escapeShellArg personal.backupDirectory}
        mkdir -p "$backup_dir"
        target="$backup_dir/hermes-$(date +%F-%H%M%S).zip.age"
        podman exec --user 10000:10000 ${hermes.podmanName} \
          cat /opt/data/backups/hermes.zip \
          | age --recipient ${lib.escapeShellArg personal.backupRecipient} --output "$target.part"
        chmod 600 "$target.part"
        mv "$target.part" "$target"
      '';
    };

    systemd.timers.hermes-backup = lib.mkIf backupEnabled {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 03:30:00 Asia/Shanghai";
        Persistent = true;
      };
    };
  };
}
