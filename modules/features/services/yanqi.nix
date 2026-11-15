{ images, lib, ... }:

{
  ray.features."services/yanqi" = {
    requires.allOf = [
      "security/agenix"
      "virtualisation/podman"
    ];

    options = {
      account = lib.mkOption {
        type = lib.types.str;
        description = "QQ account to log in automatically using the saved NapCat session.";
      };

      napcat = {
        webPort = lib.mkOption {
          type = lib.types.port;
          description = "Host port for NapCat's web interface.";
        };
      };
    };

    nixos =
      { settings, ... }:
      { config, ... }:
      let
        inherit (config.virtualisation.quadlet) containers networks volumes;
      in
      {
        networking.firewall.interfaces.br-yanqi = {
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };

        virtualisation.quadlet = {
          volumes = {
            yanqi = { };
            yanqi-napcat-qq = { };
            yanqi-napcat-config = { };
          };

          networks.yanqi.networkConfig = {
            NetworkName = "yanqi";
            InterfaceName = "br-yanqi";
          };

          containers = {
            yanqi-napcat.containerConfig = {
              Image = images.napcat;
              Network = [ networks.yanqi.ref ];
              NetworkAlias = [ "napcat" ];
              PublishPort = [ "${toString settings.napcat.webPort}:6099" ];
              Volume = [
                "${volumes.yanqi-napcat-qq.ref}:/app/.config/QQ"
                "${volumes.yanqi-napcat-config.ref}:/app/napcat/config"
              ];
              Environment = {
                NAPCAT_QUICK_ACCOUNT = settings.account;
                MODE = "ws";
                NAPCAT_UID = "1000";
                NAPCAT_GID = "1000";
                TZ = config.time.timeZone;
              };
              EnvironmentFile = [ config.age.secrets.yanqi-napcat-env.path ];
            };

            yanqi = {
              unitConfig = {
                Wants = [ containers.yanqi-napcat.ref ];
                After = [ containers.yanqi-napcat.ref ];
              };
              containerConfig = {
                Image = images.yanqi;
                Network = [ networks.yanqi.ref ];
                NetworkAlias = [ "yanqi" ];
                PublishPort = [ "3210:3000" ];
                Volume = [ "${volumes.yanqi.ref}:/app/data" ];
                Environment.TZ = config.time.timeZone;
                NoNewPrivileges = true;
              };
            };
          };
        };

        systemd.services.${containers.yanqi-napcat.serviceName}.restartTriggers = [
          config.age.secrets.yanqi-napcat-env.file
        ];
      };
  };
}
