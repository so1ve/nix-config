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
        mergedSettings = settings.settings // {
          exec = systemdExec ++ (settings.settings.exec or [ ]);
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
          ++ settings.extraPackages;
        };

        systemd.services.uptarn-agent.restartTriggers = [
          config.age.secrets.${settings.tokenSecret}.file
        ];
      };
  };
}
