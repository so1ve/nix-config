{ lib, ... }:

{
  ray.features."services/cinny" = {
    requires.allOf = [
      "virtualisation/podman"
      "services/cloudflared"
      "services/matrix"
    ];

    options = {
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start the Cinny Matrix web client automatically.";
      };

      homeserver = lib.mkOption {
        type = lib.types.str;
        description = "Public Matrix homeserver hostname.";
      };
    };

    nixos =
      { settings, ... }:
      {
        config,
        pkgs,
        ...
      }:
      let
        inherit (config.virtualisation.quadlet) containers networks;
        clientConfig = pkgs.writeText "cinny-config.json" (
          builtins.toJSON {
            defaultHomeserver = 0;
            homeserverList = [ settings.homeserver ];
            allowCustomHomeservers = false;
            hashRouter = {
              enabled = false;
              basename = "/";
            };
          }
        );
        # to use non-privileged nginx, we need to run it on a non-privileged port (8080)
        nginxConfig = pkgs.writeText "cinny-nginx.conf" ''
          worker_processes auto;
          pid /tmp/nginx.pid;
          error_log /dev/stderr warn;

          events {
            worker_connections 1024;
          }

          http {
            include /etc/nginx/mime.types;
            default_type application/octet-stream;

            access_log /dev/stdout;
            client_body_temp_path /tmp/client_temp;
            proxy_temp_path /tmp/proxy_temp;
            fastcgi_temp_path /tmp/fastcgi_temp;
            uwsgi_temp_path /tmp/uwsgi_temp;
            scgi_temp_path /tmp/scgi_temp;

            sendfile on;
            keepalive_timeout 65;

            server {
              listen 8080;
              listen [::]:8080;

              root /app;
              index index.html;

              location / {
                try_files $uri $uri/ /index.html;
              }
            }
          }
        '';
      in
      {
        virtualisation.quadlet.containers.cinny = {
          inherit (settings) autoStart;
          unitConfig = {
            Requires = [
              containers.cloudflared.ref
              containers.tuwunel.ref
            ];
            After = [
              containers.cloudflared.ref
              containers.tuwunel.ref
            ];
          };
          serviceConfig = {
            Restart = "always";
            TimeoutStartSec = "5min";
          };
          containerConfig = {
            ContainerName = "cinny";
            Image = "ghcr.io/cinnyapp/cinny:latest";
            Entrypoint = "/usr/sbin/nginx";
            Exec = "-g 'daemon off;'";
            User = "101:101";
            Network = [ networks.cloudflared.ref ];
            NetworkAlias = [ "cinny" ];
            NoNewPrivileges = true;
            DropCapability = [ "ALL" ];
            ReadOnly = true;
            Tmpfs = "/tmp";
            Volume = [
              "${clientConfig}:/app/config.json:ro"
              "${nginxConfig}:/etc/nginx/nginx.conf:ro"
            ];
          };
        };
      };
  };
}
