{
  ray.features."software/naive" = {
    requires.allOf = [ "security/agenix" ];

    nixos =
      _:
      { config, ... }:
      {
        # Mihomo connects to this local SOCKS endpoint; sing-box supplies Cronet.
        services.sing-box = {
          enable = true;
          settings = {
            log.level = "warn";
            inbounds = [
              {
                type = "socks";
                listen = "127.0.0.1";
                listen_port = 1081;
              }
            ];
            outbounds = [
              {
                _secret = config.age.secrets.naive-client.path;
                quote = false;
              }
            ];
          };
        };

        systemd.services.sing-box = {
          restartTriggers = [ config.age.secrets.naive-client.file ];
          serviceConfig = {
            CapabilityBoundingSet = [ "" ];
            AmbientCapabilities = [ "" ];
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
          };
        };
      };
  };
}
