{ lib, ... }:

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
              Image = "docker.io/mlikiowa/napcat-docker@sha256:696e9574a0f6fb2f86cbecba8a32048f2a5823117dc9b13c6c02637ad890fa8b";
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
                NAPCAT_UID = toString config.users.users.media.uid;
                NAPCAT_GID = toString config.users.groups.media.gid;
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
                Image = "ghcr.io/so1ve/yanqi@sha256:eaf60e9505b11fde9cf92cb0ac897c2e6d7b5b70416301a98e2510a3922d58ce";
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
