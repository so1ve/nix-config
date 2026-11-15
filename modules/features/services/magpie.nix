{ lib, ... }:

{
  ray.features."services/magpie" = {
    requires.allOf = [ "security/agenix" ];

    options.gatewayAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:3425";
      description = "Listen address and port of the model gateway.";
    };

    nixos =
      { settings, ... }:
      { config, pkgs, ... }:
      {
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
            pkgs.bash
            pkgs.curl
          ];
          environment = {
            HOME = "/var/lib/magpie";
            MAGPIE_ADDR = settings.gatewayAddress;
          };
          restartTriggers = [ config.age.secrets.magpie-env.file ];
          serviceConfig = {
            User = "magpie";
            Group = "magpie";
            StateDirectory = "magpie";
            StateDirectoryMode = "0700";
            WorkingDirectory = "/var/lib/magpie";
            EnvironmentFile = config.age.secrets.magpie-env.path;
            ExecStart = "${pkgs.so1ve.magpie}/bin/magpie serve --web=127.0.0.1:3430";
            Restart = "on-failure";
            RestartSec = 2;
            UMask = "0077";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
          };
        };
      };
  };
}
