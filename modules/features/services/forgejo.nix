{ lib, ... }:

{
  ray.features."services/forgejo" = {
    requires.allOf = [ "services/cloudflared" ];

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
      { settings, ... }:
      { config, pkgs, ... }:
      let
        cfg = config.services.forgejo;
      in
      {
        services.forgejo = {
          enable = true;
          package = pkgs.forgejo;
          database.path = "${cfg.stateDir}/data/gitea.db";
          repositoryRoot = "${cfg.stateDir}/git/repositories";
          lfs = {
            enable = true;
            contentDir = "${cfg.stateDir}/git/lfs";
          };
          settings = {
            DEFAULT.APP_NAME = settings.domain;
            ui = {
              DEFAULT_THEME = "so1ve-auto";
              THEMES = "so1ve-auto,so1ve-light,so1ve-dark,forgejo-auto";
            };
            server = {
              ROOT_URL = "https://${settings.domain}/";
              DOMAIN = settings.domain;
              HTTP_ADDR = "127.0.0.1";
              HTTP_PORT = 3000;
              APP_DATA_PATH = cfg.stateDir;
              DISABLE_SSH = true;
              START_SSH_SERVER = false;
            };
            repository = {
              DEFAULT_BRANCH = "main";
              DEFAULT_PRIVATE = "public";
              DEFAULT_PUSH_CREATE_PRIVATE = false;
              ENABLE_PUSH_CREATE_USER = true;
              ENABLE_PUSH_CREATE_ORG = true;
            };
            session.PROVIDER_CONFIG = "${cfg.stateDir}/data/sessions";
            picture = {
              AVATAR_UPLOAD_PATH = "${cfg.stateDir}/data/avatars";
              REPOSITORY_AVATAR_UPLOAD_PATH = "${cfg.stateDir}/data/repo-avatars";
            };
            attachment.PATH = "${cfg.stateDir}/data/attachments";
            log.ROOT_PATH = "${cfg.stateDir}/data/log";
            oauth2_client = {
              ACCOUNT_LINKING = "auto";
              ENABLE_AUTO_REGISTRATION = true;
              UPDATE_AVATAR = true;
              USERNAME = "preferred_username";
            };
            service = {
              DISABLE_REGISTRATION = true;
              REQUIRE_SIGNIN_VIEW = true;
              ENABLE_INTERNAL_SIGNIN = false;
              ENABLE_BASIC_AUTHENTICATION = false;
            };
          };
        };

        systemd.services.forgejo = {
          wantedBy = lib.mkForce (lib.optional settings.autoStart "multi-user.target");
          serviceConfig.BindReadOnlyPaths = [
            "${./forgejo/templates}:${cfg.customDir}/templates"
            "${./forgejo/public}:${cfg.customDir}/public"
          ];
        };
      };
  };
}
