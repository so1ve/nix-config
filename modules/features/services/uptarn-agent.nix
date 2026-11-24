{ lib, ... }:

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
        description = "Extra packages added to PATH for [[exec]] checks.";
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
        description = "Report Tailscale daemon status; defaults to services.tailscale.enable.";
      };

      podmanCheck = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Summarize quadlet Podman container unit states; defaults to virtualisation.podman.enable.";
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

        systemdExec = lib.optional settings.systemdCheck {
          key = "systemd";
          label = "systemd";
          group = "system";
          command = [
            "sh"
            "-c"
            "u=$(systemctl list-units --state=failed --no-legend --plain | awk '{print $1}'); [ -z \"$u\" ] && echo '0 failed units' || { echo \"failed: $(echo \"$u\" | paste -sd, -)\"; exit 1; }"
          ];
        };

        rebootExec = lib.optional settings.rebootCheck {
          key = "reboot";
          label = "Kernel";
          group = "system";
          warn_exit_code = 2;
          command = [
            "sh"
            "-c"
            "b=$(readlink -f /run/booted-system/kernel); c=$(readlink -f /run/current-system/kernel); [ \"$b\" = \"$c\" ] && echo 'up to date' || { echo 'reboot required'; echo \"booted:  $b\"; echo \"current: $c\"; exit 2; }"
          ];
        };

        tailscaleExec = lib.optional enableTailscaleCheck {
          key = "tailscale";
          label = "Tailscale";
          group = "network";
          command = [
            "sh"
            "-c"
            "systemctl is-active --quiet tailscaled.service || { echo 'tailscaled inactive'; exit 1; }; line=$(tailscale status --peers=false 2>&1) || { echo \"$line\"; exit 1; }; ip=$(echo \"$line\" | awk 'NR==1 {print $1}'); [ -n \"$ip\" ] && echo \"$ip\" || { echo 'not connected'; exit 1; }"
          ];
        };

        podmanExec = lib.optional enablePodmanCheck {
          key = "containers";
          label = "Containers";
          group = "services";
          warn_exit_code = 2;
          command = [
            "sh"
            "-c"
            ''
              systemctl list-units --type=service --all --no-legend --plain | awk '
                /Podman container / {
                  total++
                  name = $1
                  sub(/\.service$/, "", name)
                  if ($3 == "active" && $4 == "running") {
                    running++
                    ok_list = ok_list (ok_list ? "\n" : "") name ": running"
                  } else if ($3 == "activating") {
                    starting++
                    bad_list = bad_list (bad_list ? "\n" : "") name ": " $3 "/" $4
                  } else {
                    down++
                    bad_list = bad_list (bad_list ? "\n" : "") name ": " $3 "/" $4
                  }
                }
                END {
                  if (total == 0) {
                    print "0 containers"
                    exit 0
                  }
                  if (down > 0) {
                    printf "%d/%d running (%d down)\n", running, total, down
                    print bad_list
                    exit 1
                  }
                  if (starting > 0) {
                    printf "%d/%d running (%d starting)\n", running, total, starting
                    print bad_list
                    exit 2
                  }
                  printf "%d/%d running\n", running, total
                  print ok_list
                }'
            ''
          ];
        };

        mergedSettings = settings.settings // {
          exec = systemdExec ++ rebootExec ++ tailscaleExec ++ podmanExec ++ (settings.settings.exec or [ ]);
        };
      in
      {
        imports = [ inputs.uptarn.nixosModules.agent ];

        services.uptarn-agent = {
          enable = true;
          inherit (settings) hubUrl;
          settings = mergedSettings;
          tokenFile = config.age.secrets.${settings.tokenSecret}.path;
          extraPackages = [
            pkgs.bash
            pkgs.coreutils
            pkgs.gawk
            pkgs.systemd
          ]
          ++ lib.optional enableTailscaleCheck pkgs.tailscale
          ++ settings.extraPackages;
        };

        systemd.services.uptarn-agent.restartTriggers = [
          config.age.secrets.${settings.tokenSecret}.file
        ];
      };
  };
}
