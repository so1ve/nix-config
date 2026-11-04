{ lib, ... }:

{
  ray.features."services/forgejo" = {
    requires.allOf = [
      "security/agenix"
      "virtualisation/podman"
      "services/cloudflared"
    ];

    options = {
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start Forgejo automatically.";
      };

      domain = lib.mkOption {
        type = lib.types.str;
        description = "Public hostname served for Forgejo.";
      };
    };

    nixos =
      settings:
      { config, ... }:
      let
        inherit (config.virtualisation.quadlet) containers networks;
      in
      {
        systemd.tmpfiles.rules = [
          "d /var/lib/forgejo 0700 1000 1000 - -"
        ];

        virtualisation.quadlet.containers.forgejo = {
          inherit (settings) autoStart;
          unitConfig = {
            Requires = containers.cloudflared.ref;
            After = containers.cloudflared.ref;
          };
          serviceConfig = {
            Restart = "always";
            TimeoutStartSec = "5min";
          };
          containerConfig = {
            ContainerName = "forgejo";
            Image = "codeberg.org/forgejo/forgejo:17-rootless";
            User = "1000:1000";
            Network = [ networks.cloudflared.ref ];
            NetworkAlias = [ "forgejo" ];
            NoNewPrivileges = true;
            DropCapability = [ "ALL" ];
            Volume = [ "/var/lib/forgejo:/var/lib/gitea" ];
            Environment = {
              USER_UID = "1000";
              USER_GID = "1000";
              FORGEJO__server__ROOT_URL = "https://${settings.domain}/";
              FORGEJO__server__DOMAIN = settings.domain;
              FORGEJO__server__HTTP_PORT = "3000";
              FORGEJO__server__DISABLE_SSH = "true";
              FORGEJO__server__START_SSH_SERVER = "false";
              FORGEJO__repository__DEFAULT_BRANCH = "main";
              FORGEJO__security__INSTALL_LOCK = "true";
              FORGEJO__oauth2_client__ENABLE_AUTO_REGISTRATION = "true";
              FORGEJO__service__DISABLE_REGISTRATION = "true";
              FORGEJO__service__REQUIRE_SIGNIN_VIEW = "true";
            };
            EnvironmentFile = [ config.age.secrets.forgejo-env.path ];
          };
        };

        systemd.services.forgejo.restartTriggers = [ config.age.secrets.forgejo-env.file ];
      };
  };
}
