{ lib, ... }:

let
  unitCheckType = lib.types.submodule {
    options = {
      key = lib.mkOption {
        type = lib.types.str;
        description = "Check key reported to Uptarn.";
      };

      label = lib.mkOption {
        type = lib.types.str;
        description = "Display label for the check.";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "services";
        description = "Check group name.";
      };

      unit = lib.mkOption {
        type = lib.types.str;
        description = "Systemd unit name to monitor (e.g. cloudflared.service).";
      };

      timer = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional triggering timer unit for oneshot services (e.g. ddclient.timer).";
      };
    };
  };

  timerJobType = lib.types.submodule {
    options = {
      key = lib.mkOption {
        type = lib.types.str;
        description = "Job key reported to Uptarn.";
      };

      label = lib.mkOption {
        type = lib.types.str;
        description = "Display label for the job.";
      };

      unit = lib.mkOption {
        type = lib.types.str;
        description = "Systemd service unit name (e.g. restic-backups-homelab.service).";
      };

      timer = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional triggering systemd timer unit name.";
      };

      schedule = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional human-readable schedule label shown in the Jobs view.";
      };
    };
  };
in
{
  ray.features."services/uptarn-agent" = {
    requires.allOf = [ "security/agenix" ];

    options = {
      hubUrl = lib.mkOption {
        type = lib.types.str;
        description = "Base URL of the Uptarn hub.";
      };

      tokenSecret = lib.mkOption {
        type = lib.types.str;
        default = "uptarn-agent-token";
        description = "Declared agenix secret containing the node Bearer token.";
      };

      extraPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Extra packages added to PATH for custom [[collectors]] and exec [[monitors]].";
      };

      systemdCheck = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Report failed systemd units as a check.";
      };

      rebootCheck = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Warn when the running kernel differs from /run/current-system/kernel.";
      };

      tailscaleCheck = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Report Tailscale status and IP; defaults to services.tailscale.enable.";
      };

      podmanCheck = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Summarize quadlet Podman container unit states; defaults to virtualisation.podman.enable.";
      };

      hostInfo = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Report host IPv4/IPv6, CPU model, NixOS version, and generation in System info.";
      };

      unitChecks = lib.mkOption {
        type = lib.types.listOf unitCheckType;
        default = [ ];
        description = "Systemd service or timer checks reported as [[collectors]].";
      };

      timerJobs = lib.mkOption {
        type = lib.types.listOf timerJobType;
        default = [ ];
        description = "Systemd timer-driven services reported as Jobs via collector JSON.";
      };

      settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional agent.toml configuration passed to services.uptarn-agent.settings.";
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
        enableTailscaleCheck =
          if settings.tailscaleCheck != null then
            settings.tailscaleCheck
          else
            config.services.tailscale.enable;
        enablePodmanCheck =
          if settings.podmanCheck != null then settings.podmanCheck else config.virtualisation.podman.enable;

        mkScript =
          name: file: runtimeInputs:
          lib.getExe (
            pkgs.writeShellApplication {
              name = "uptarn-check-${name}";
              inherit runtimeInputs;
              text = builtins.readFile (./uptarn-agent + "/${file}");
            }
          );

        systemdScript = mkScript "systemd" "systemd.sh" [
          pkgs.coreutils
          pkgs.gawk
          pkgs.systemd
        ];
        rebootScript = mkScript "reboot" "reboot.sh" [ pkgs.coreutils ];
        tailscaleScript = mkScript "tailscale" "tailscale.sh" [
          pkgs.gawk
          pkgs.jq
          pkgs.systemd
          pkgs.tailscale
        ];
        containersScript = mkScript "containers" "containers.sh" [
          pkgs.gawk
          pkgs.systemd
        ];
        hostInfoScript = mkScript "host-info" "host-info.sh" [
          pkgs.coreutils
          pkgs.gawk
          pkgs.gnused
          pkgs.iproute2
          pkgs.jq
        ];
        unitScript = mkScript "unit" "unit.sh" [ pkgs.systemd ];
        systemdJobScript = mkScript "systemd-job" "systemd-job.sh" [
          pkgs.coreutils
          pkgs.jq
          pkgs.systemd
        ];

        systemdExec = lib.optional settings.systemdCheck {
          key = "systemd";
          label = "systemd";
          group = "system";
          command = [ systemdScript ];
        };

        rebootExec = lib.optional settings.rebootCheck {
          key = "reboot";
          label = "Kernel";
          group = "system";
          warn_exit_code = 2;
          command = [ rebootScript ];
        };

        tailscaleExec = lib.optional enableTailscaleCheck {
          key = "tailscale";
          label = "Tailscale";
          group = "network";
          format = "json";
          command = [ tailscaleScript ];
        };

        podmanExec = lib.optional enablePodmanCheck {
          key = "containers";
          label = "Containers";
          group = "services";
          warn_exit_code = 2;
          command = [ containersScript ];
        };

        hostInfoExec = lib.optional settings.hostInfo {
          key = "host_info";
          label = "Host Info";
          format = "json";
          command = [ hostInfoScript ];
        };

        unitExecs = map (c: {
          inherit (c) key label group;
          command = [
            unitScript
            c.unit
          ]
          ++ lib.optional (c.timer != null) c.timer;
        }) (config.ray.uptarn.unitChecks ++ settings.unitChecks);

        timerJobExecs = map (j: {
          key = "job.${j.key}";
          inherit (j) label;
          format = "json";
          command = [
            systemdJobScript
            j.key
            j.label
            j.unit
            (if j.timer != null then j.timer else "")
          ]
          ++ lib.optional (j.schedule != null) j.schedule;
        }) (config.ray.uptarn.timerJobs ++ settings.timerJobs);

        allMonitors = config.ray.uptarn.monitors ++ (settings.settings.monitors or [ ]);

        mergedSettings =
          (builtins.removeAttrs settings.settings [ "checks" ])
          // {
            collectors =
              systemdExec
              ++ rebootExec
              ++ tailscaleExec
              ++ podmanExec
              ++ unitExecs
              ++ timerJobExecs
              ++ config.ray.uptarn.collectors
              ++ hostInfoExec
              ++ (settings.settings.collectors or [ ]);
          }
          // lib.optionalAttrs (config.ray.uptarn.monitors != [ ] || settings.settings ? monitors) {
            monitors = allMonitors;
          };
      in
      {
        imports = [ inputs.uptarn.nixosModules.agent ];

        options.ray.uptarn = {
          unitChecks = lib.mkOption {
            type = lib.types.listOf unitCheckType;
            default = [ ];
            description = "Systemd unit checks registered by other NixOS features.";
          };

          collectors = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [ ];
            description = "Custom [[collectors]] entries registered by other NixOS features.";
          };

          timerJobs = lib.mkOption {
            type = lib.types.listOf timerJobType;
            default = [ ];
            description = "Systemd timer-driven jobs registered by other NixOS features.";
          };

          monitors = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [ ];
            description = "Agent-managed [[monitors]] entries registered by other NixOS features.";
          };
        };

        config = {
          services.uptarn-agent = {
            enable = true;
            inherit (settings) hubUrl extraPackages;
            settings = mergedSettings;
            tokenFile = config.age.secrets.${settings.tokenSecret}.path;
          };

          systemd.services.uptarn-agent.restartTriggers = [
            config.age.secrets.${settings.tokenSecret}.file
            config.environment.etc."uptarn/agent.toml".source
          ];
        };
      };
  };
}
