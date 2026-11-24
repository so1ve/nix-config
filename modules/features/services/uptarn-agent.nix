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

      hostInfo = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Report host IPv4/IPv6, CPU model, NixOS version, and generation in System info.";
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
          format = "json";
          command = [
            "sh"
            "-c"
            ''
              if ! systemctl is-active --quiet tailscaled.service; then
                printf '{"checks":[{"key":"tailscale","label":"Tailscale","group":"network","status":"fail","summary":"stopped"}]}\n'
                exit 0
              fi
              line=$(tailscale status --peers=false 2>&1) || {
                msg=$(printf '%s' "$line" | head -n 1 | tr '"\n\r' "'  ")
                printf '{"checks":[{"key":"tailscale","label":"Tailscale","group":"network","status":"fail","summary":"%s"}]}\n' "$msg"
                exit 0
              }
              ip=$(printf '%s\n' "$line" | awk 'NR==1 {print $1}')
              if [ -n "$ip" ]; then
                printf '{"checks":[{"key":"tailscale","label":"Tailscale","group":"network","status":"ok","summary":"active"}],"info":[{"key":"tailscale_ip","label":"Tailscale IP","group":"network","value":"%s"}]}\n' "$ip"
              else
                printf '{"checks":[{"key":"tailscale","label":"Tailscale","group":"network","status":"fail","summary":"disconnected"}]}\n'
              fi
            ''
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

        hostInfoExec = lib.optional settings.hostInfo {
          key = "host_info";
          label = "Host Info";
          format = "json";
          command = [
            "sh"
            "-c"
            ''
              cpu=$(awk -F: '/^model name/{gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null)
              ipv4=$(ip -4 -o addr show scope global 2>/dev/null \
                | awk '$2 !~ /^(lo|tailscale|docker|podman|br-|veth|cni|virbr|wg|tun|tap)/ {sub(/\/.*/, "", $4); print $4; exit}')
              ipv6=$(ip -6 -o addr show scope global -deprecated -temporary 2>/dev/null \
                | awk '$2 !~ /^(lo|tailscale|docker|podman|br-|veth|cni|virbr|wg|tun|tap)/ && $4 !~ /^(fd|fc)/ {sub(/\/.*/, "", $4); print length($4), $4}' \
                | sort -n | awk 'NR==1 {print $2}')
              nixos_ver=$(cat /run/current-system/nixos-version 2>/dev/null || true)
              gen_link=$(readlink /nix/var/nix/profiles/system 2>/dev/null || true)
              gen_num=$(printf '%s' "$gen_link" | sed -n 's/^system-\([0-9]*\)-link$/\1/p')
              gen_str=""
              if [ -n "$gen_num" ]; then
                gen_date=$(date -r "/nix/var/nix/profiles/$gen_link" +%Y-%m-%d 2>/dev/null || true)
                if [ -n "$gen_date" ]; then
                  gen_str="#$gen_num ($gen_date)"
                else
                  gen_str="#$gen_num"
                fi
              fi

              jq -n \
                --arg cpu "$cpu" \
                --arg ipv4 "$ipv4" \
                --arg ipv6 "$ipv6" \
                --arg nixos_ver "$nixos_ver" \
                --arg gen_str "$gen_str" \
                '{
                  info: [
                    (if $cpu != "" then { key: "cpu_model", label: "CPU Model", group: "system", value: $cpu } else empty end),
                    (if $ipv4 != "" then { key: "ipv4", label: "IPv4", group: "network", value: $ipv4 } else empty end),
                    (if $ipv6 != "" then { key: "ipv6", label: "IPv6", group: "network", value: $ipv6 } else empty end),
                    (if $nixos_ver != "" then { key: "nixos_version", label: "NixOS", group: "system", value: $nixos_ver } else empty end),
                    (if $gen_str != "" then { key: "generation", label: "Generation", group: "system", value: $gen_str } else empty end)
                  ]
                }'
            ''
          ];
        };

        mergedSettings = settings.settings // {
          exec =
            systemdExec
            ++ rebootExec
            ++ tailscaleExec
            ++ podmanExec
            ++ hostInfoExec
            ++ (settings.settings.exec or [ ]);
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
            pkgs.gnused
            pkgs.systemd
          ]
          ++ lib.optionals settings.hostInfo [
            pkgs.iproute2
            pkgs.jq
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
