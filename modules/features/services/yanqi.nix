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

      napcat.uid = lib.mkOption {
        type = lib.types.ints.unsigned;
        description = "User ID for NapCat's persistent container data.";
      };

      napcat.gid = lib.mkOption {
        type = lib.types.ints.unsigned;
        description = "Group ID for NapCat's persistent container data.";
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
            napcat-qq = { };
            napcat-config = { };
          };

          networks.yanqi.networkConfig = {
            NetworkName = "yanqi";
            InterfaceName = "br-yanqi";
          };

          containers = {
            napcat.containerConfig = {
              Image = images.napcat;
              Network = [ networks.yanqi.ref ];
              NetworkAlias = [ "napcat" ];
              PublishPort = [ "6100:6099" ];
              Volume = [
                "${volumes.napcat-qq.ref}:/app/.config/QQ"
                "${volumes.napcat-config.ref}:/app/napcat/config"
              ];
              Environment = {
                NAPCAT_QUICK_ACCOUNT = settings.account;
                MODE = "ws";
                NAPCAT_UID = toString settings.napcat.uid;
                NAPCAT_GID = toString settings.napcat.gid;
                TZ = config.time.timeZone;
              };
              EnvironmentFile = [ config.age.secrets.napcat-env.path ];
            };
            yanqi = {
              unitConfig = {
                Wants = [ containers.napcat.ref ];
                After = [ containers.napcat.ref ];
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

        systemd.services.${containers.napcat.serviceName}.restartTriggers = [
          config.age.secrets.napcat-env.file
        ];
      };
  };
}
