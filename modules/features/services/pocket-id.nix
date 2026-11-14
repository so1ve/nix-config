{ lib, ... }:

{
  ray.features."services/pocket-id" = {
    requires.allOf = [
      "security/agenix"
      "services/cloudflared"
    ];

    options = {
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start Pocket ID automatically.";
      };

      publicUrl = lib.mkOption {
        type = lib.types.str;
        description = "Public base URL of the Pocket ID instance.";
      };
    };

    nixos =
      { settings, ... }:
      { config, pkgs, ... }:
      {
        services.pocket-id = {
          enable = true;
          package = pkgs.so1ve.pocket-id;
          environmentFile = config.age.secrets.pocket-id-env.path;
          settings = {
            APP_URL = settings.publicUrl;
            HOST = "127.0.0.1";
            PORT = 1411;
            DB_CONNECTION_STRING = "/var/lib/pocket-id/pocket-id.db";
            UPLOAD_PATH = "/var/lib/pocket-id/uploads";
            GEOLITE_DB_PATH = "/var/lib/pocket-id/GeoLite2-City.mmdb";
            TRUST_PROXY = true;
            ALLOW_USER_SIGNUPS = "withToken";
            UI_CONFIG_DISABLED = true;
          };
        };

        systemd.tmpfiles.rules = [
          "z /var/lib/pocket-id 0700 pocket-id pocket-id - -"
        ];

        systemd.services.pocket-id = {
          wantedBy = lib.mkForce (lib.optional settings.autoStart "multi-user.target");
          restartTriggers = [ config.age.secrets.pocket-id-env.file ];
        };
      };
  };
}
