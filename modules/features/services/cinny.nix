{ lib, ... }:

{
  ray.features."services/cinny" = {
    requires.allOf = [ "services/cloudflared" ];

    options = {
      domain = lib.mkOption {
        type = lib.types.str;
        description = "Public hostname of the Cinny Matrix web client.";
      };

      homeserver = lib.mkOption {
        type = lib.types.str;
        description = "Public Matrix homeserver hostname.";
      };
    };

    nixos =
      { settings, ... }:
      { pkgs, ... }:
      let
        client = pkgs.cinny.override {
          conf = {
            defaultHomeserver = 0;
            homeserverList = [ settings.homeserver ];
            allowCustomHomeservers = false;
            hashRouter = {
              enabled = false;
              basename = "/";
            };
          };
        };
      in
      {
        services.caddy = {
          enable = true;
          virtualHosts."http://${settings.domain}:8081".extraConfig = ''
            bind 127.0.0.1
            root * ${client}
            try_files {path} /index.html
            file_server
          '';
        };
      };
  };
}
