{
  config,
  inputs,
  lib,
  ...
}:

let
  inherit (lib) mkOption types;

  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  cfg = config.ray.uptarn;

  nodeType = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        description = "Registered Uptarn node identifier.";
      };

      isPublic = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Whether the node appears on the public status page (null leaves unchanged).";
      };

      primaryMount = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Mount path used for node disk summary (null sums all reported mounts).";
      };
    };
  };

  monitorType = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        description = "Stable monitor identifier used for declarative reconciliation.";
      };

      name = mkOption {
        type = types.str;
        description = "Display name of the monitor.";
      };

      url = mkOption {
        type = types.str;
        description = "HTTP(S) endpoint URL to probe.";
      };

      publicUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional public link URL shown on the status page.";
      };

      method = mkOption {
        type = types.enum [
          "GET"
          "HEAD"
          "POST"
        ];
        default = "GET";
        description = "HTTP method used for probing.";
      };

      expectedStatusMin = mkOption {
        type = types.ints.between 100 599;
        default = 200;
        description = "Minimum acceptable HTTP status code.";
      };

      expectedStatusMax = mkOption {
        type = types.nullOr (types.ints.between 100 599);
        default = null;
        description = "Maximum acceptable HTTP status code (defaults to max(299, expectedStatusMin)).";
      };

      expectedBody = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional substring required in the HTTP response body.";
      };

      timeoutMs = mkOption {
        type = types.ints.between 500 30000;
        default = 8000;
        description = "HTTP probe timeout in milliseconds.";
      };

      intervalSecs = mkOption {
        type = types.ints.between 30 86400;
        default = 60;
        description = "Probe interval in seconds.";
      };

      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the monitor is actively probed.";
      };

      isPublic = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the monitor appears on the public status page.";
      };
    };
  };

  renderNode =
    node:
    {
      inherit (node) id;
      primary_mount = node.primaryMount;
    }
    // lib.optionalAttrs (node.isPublic != null) {
      is_public = node.isPublic;
    };

  renderMonitor =
    mon:
    {
      inherit (mon)
        id
        name
        url
        method
        enabled
        ;
      expected_status_min = mon.expectedStatusMin;
      timeout_ms = mon.timeoutMs;
      interval_secs = mon.intervalSecs;
      is_public = mon.isPublic;
    }
    // lib.optionalAttrs (mon.publicUrl != null) {
      public_url = mon.publicUrl;
    }
    // lib.optionalAttrs (mon.expectedStatusMax != null) {
      expected_status_max = mon.expectedStatusMax;
    }
    // lib.optionalAttrs (mon.expectedBody != null) {
      expected_body = mon.expectedBody;
    };

  syncSpec =
    lib.optionalAttrs (cfg.hubUrl != null) {
      hub_url = cfg.hubUrl;
    }
    // lib.optionalAttrs (cfg.autoRegister != null) {
      auto_register = cfg.autoRegister;
    }
    // lib.optionalAttrs (cfg.nodes != null) {
      nodes = map renderNode cfg.nodes;
    }
    // lib.optionalAttrs (cfg.monitors != null) {
      monitors = map renderMonitor cfg.monitors;
    };

  uptarnConfig = (pkgs.formats.json { }).generate "uptarn-config.json" syncSpec;

  uptarnCommand = pkgs.writeShellApplication {
    name = "uptarn-ctl";
    runtimeInputs = [
      cfg.package
      pkgs.coreutils
      pkgs.gnused
      pkgs.rage
    ];
    text = ''
      set -euo pipefail

      token_tmp=""
      cleanup() {
        if [[ -n "$token_tmp" ]]; then
          rm -f "$token_tmp"
        fi
      }
      trap cleanup EXIT

      ${lib.optionalString (cfg.hubUrl != null) ''
        export UPTARN_SERVER="''${UPTARN_SERVER:-${cfg.hubUrl}}"
      ''}

      ${lib.optionalString (cfg.secretFile != null) ''
        if [[ -z "''${UPTARN_ADMIN_TOKEN:-}" && -z "''${UPTARN_ADMIN_TOKEN_FILE:-}" ]]; then
          identity="''${AGENIX_IDENTITY:-$HOME/.config/agenix/identity}"
          token_tmp="$(mktemp)"
          chmod 600 "$token_tmp"
          rage -d -i "$identity" ${lib.escapeShellArg (toString cfg.secretFile)} \
            | sed -n 's/^admin_token:[[:space:]]*//p' \
            | tr -d "\"'\r" \
            > "$token_tmp"
          export UPTARN_ADMIN_TOKEN_FILE="$token_tmp"
        fi
      ''}

      cmd="''${1:-}"
      case "$cmd" in
        plan)
          shift
          uptarn sync ${uptarnConfig} --dry-run "$@"
          ;;
        apply)
          shift
          uptarn sync ${uptarnConfig} "$@"
          ;;
        config)
          cat ${uptarnConfig}
          ;;
        *)
          uptarn "$@"
          ;;
      esac
    '';
  };
in
{
  options.ray.uptarn = {
    package = mkOption {
      type = types.package;
      default = inputs.uptarn.packages.${system}.uptarn;
      description = "Uptarn CLI package used to reconcile the hub.";
    };

    hubUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://status.example.com";
      description = "Base URL of the Uptarn hub.";
    };

    autoRegister = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Declarative auto-registration toggle (null leaves unchanged).";
    };

    secretFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional age-encrypted YAML file containing admin_token.";
    };

    nodes = mkOption {
      type = types.nullOr (types.listOf nodeType);
      default = null;
      description = "Ordered list of nodes and optional public visibility overrides.";
    };

    monitors = mkOption {
      type = types.nullOr (types.listOf monitorType);
      default = null;
      description = "Ordered list of hub-managed HTTP monitors.";
    };
  };

  config.outputs = _: {
    packages.${system} = {
      uptarn = uptarnCommand;
      uptarn-config = uptarnConfig;
    };
  };
}
