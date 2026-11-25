{ lib, ... }:

{
  ray.features."services/magpie" = {
    requires.allOf = [ "security/agenix" ];

    nixos =
      _:
      {
        config,
        featureEnabled,
        pkgs,
        ...
      }:
      let
        webPort = 3430;
      in
      {
        networking.firewall.allowedTCPPorts = [ webPort ];

        users.groups.magpie = { };
        users.users.magpie = {
          isSystemUser = true;
          group = "magpie";
          home = "/var/lib/magpie";
        };

        environment.systemPackages = [ pkgs.so1ve.magpie ];

        systemd.services.magpie = {
          description = "Magpie model gateway";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          path = [
            pkgs.so1ve.antigravity-cli
            pkgs.bash
            pkgs.curl
          ];
          environment = {
            HOME = "/var/lib/magpie";
            MAGPIE_ADDR = "0.0.0.0:3425";
          };
          restartTriggers = [ config.age.secrets.magpie-env.file ];
          serviceConfig = {
            User = "magpie";
            Group = "magpie";
            StateDirectory = "magpie";
            StateDirectoryMode = "0700";
            WorkingDirectory = "/var/lib/magpie";
            EnvironmentFile = config.age.secrets.magpie-env.path;
            ExecStart = "${pkgs.so1ve.magpie}/bin/magpie serve --web=0.0.0.0:${toString webPort}";
            Restart = "on-failure";
            RestartSec = 2;
            UMask = "0077";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
          };
        };
      }
      // lib.optionalAttrs (featureEnabled "services/uptarn-agent") {
        ray.uptarn.monitors = [
          {
            key = "magpie";
            name = "Magpie";
            type = "http";
            from = "agent";
            url = "http://127.0.0.1:3425/";
          }
        ];
      };
  };
}
