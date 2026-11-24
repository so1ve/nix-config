{ lib, ... }:

{
  ray.features."services/ddclient" = {
    requires = settings: {
      allOf = lib.optional (settings.environmentSecrets != [ ]) "security/agenix";
    };

    options = {
      settings = lib.mkOption {
        type = lib.types.attrs;
        description = "Options passed to the native NixOS ddclient module.";
      };

      ipv6Interface = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Interface from which to pick the newest non-temporary global IPv6 address (by preferred lifetime) via cmdv6.";
      };

      environmentSecrets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Agenix environment secrets read directly by ddclient.";
      };
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
        detectIpv6 = pkgs.writeShellApplication {
          name = "ddclient-detect-ipv6";
          runtimeInputs = [
            pkgs.iproute2
            pkgs.jq
          ];
          text = ''
            ip -6 -j addr show dev ${lib.escapeShellArg settings.ipv6Interface} scope global \
              | jq -r '
                  [ .[].addr_info[]
                    | select(
                        .family == "inet6"
                        and (.deprecated // false | not)
                        and (.temporary // false | not)
                        and (.local | test("^(fc|fd|fe[89ab])"; "i") | not)
                      )
                  ]
                  | sort_by(-(.preferred_life_time // 0), (.local | length))
                  | .[0].local // empty
                '
          '';
        };
      in
      {
        services.ddclient =
          settings.settings
          // lib.optionalAttrs (settings.ipv6Interface != null) {
            usev6 = "cmdv6, cmdv6=${lib.getExe detectIpv6}";
          }
          // {
            enable = true;
          };

        systemd.services.ddclient = {
          serviceConfig.EnvironmentFile = map (
            name: config.age.secrets.${name}.path
          ) settings.environmentSecrets;
          restartTriggers = map (name: config.age.secrets.${name}.file) settings.environmentSecrets;
        };
      }
      // lib.optionalAttrs (featureEnabled "services/uptarn-agent") {
        ray.uptarn.unitChecks = [
          {
            key = "ddclient";
            label = "DDNS";
            group = "network";
            unit = "ddclient.service";
            timer = "ddclient.timer";
          }
        ];
      };
  };
}
