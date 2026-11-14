{ lib, ... }:

{
  ray.features."services/cloudflared" = {
    requires.allOf = [ "security/agenix" ];

    options.autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start the Cloudflare Tunnel automatically.";
    };

    nixos =
      { settings, ... }:
      { config, pkgs, ... }:
      {
        systemd.services.cloudflared = {
          description = "Cloudflare Tunnel";
          wantedBy = lib.optional settings.autoStart "multi-user.target";
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          restartTriggers = [ config.age.secrets.cloudflared-env.file ];
          serviceConfig = {
            ExecStart = "${lib.getExe pkgs.cloudflared} tunnel --no-autoupdate --metrics 127.0.0.1:2000 run";
            EnvironmentFile = [ config.age.secrets.cloudflared-env.path ];
            Restart = "always";
            RestartSec = "5s";
            DynamicUser = true;
            NoNewPrivileges = true;
            CapabilityBoundingSet = "";
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
          };
        };
      };
  };
}
