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
        description = "Extra packages added to PATH for custom [[exec]] checks.";
      };

      systemdCheck = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Report failed systemd units as an [[exec]] check.";
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
        description = "Systemd service or timer checks reported as [[exec]] checks.";
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

        mergedSettings = settings.settings // {
          exec =
            systemdExec
            ++ rebootExec
            ++ tailscaleExec
            ++ podmanExec
            ++ unitExecs
            ++ config.ray.uptarn.execChecks
            ++ hostInfoExec
            ++ (settings.settings.exec or [ ]);
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

          execChecks = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [ ];
            description = "Custom [[exec]] checks registered by other NixOS features.";
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
          ];
        };
      };
  };
}
