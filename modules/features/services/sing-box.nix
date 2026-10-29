{ lib, ... }:

{
  ray.features."services/sing-box" = {
    options = {
      domain = lib.mkOption {
        type = lib.types.str;
        description = "HTTPS domain shared by VMess WebSocket and NaïveProxy.";
      };

      vmess.path = lib.mkOption {
        type = lib.types.strMatching "/[^[:space:]?#*{}]*";
        description = "Literal WebSocket request path shared by Caddy and sing-box; clients must use the same path.";
      };

      vless.port = lib.mkOption {
        type = lib.types.addCheck lib.types.port (port: port >= 1024 && port != 10000);
        description = "VLESS REALITY TCP port. Must be unprivileged and different from the internal VMess port 10000.";
      };
    };

    requires.allOf = [ "security/agenix" ];

    nixos =
      settings:
      {
        config,
        inputs,
        pkgs,
        ...
      }:
      {
        age.secrets.naive-server.owner = "caddy";

        networking.firewall.allowedTCPPorts = [
          80
          443
          settings.vless.port
        ];

        services.caddy = {
          enable = true;
          package = (import inputs.so1ve { inherit pkgs; }).caddy-naive;
          globalConfig = ''
            servers {
              protocols h1 h2
            }
          '';
          logFormat = ''
            exclude http.log.error
          '';
          virtualHosts.":443" = {
            serverAliases = [ settings.domain ];
            extraConfig = ''
              route {
                forward_proxy {
                  import ${config.age.secrets.naive-server.path}
                  hide_ip
                  hide_via
                  probe_resistance
                }
                @vmess path ${builtins.toJSON settings.vmess.path}
                reverse_proxy @vmess 127.0.0.1:10000
                respond "Not Found" 404
              }
            '';
          };
        };
        systemd.services.caddy.restartTriggers = [ config.age.secrets.naive-server.file ];

        services.sing-box = {
          enable = true;
          settings = {
            log.level = "warn";
            inbounds = [
              {
                type = "vmess";
                listen = "127.0.0.1";
                listen_port = 10000;
                users = [ { uuid._secret = config.age.secrets.sing-box-uuid.path; } ];
                transport = {
                  type = "ws";
                  path = settings.vmess.path;
                };
              }
              {
                type = "vless";
                listen = "::";
                listen_port = settings.vless.port;
                users = [
                  {
                    uuid._secret = config.age.secrets.sing-box-uuid.path;
                    flow = "xtls-rprx-vision";
                  }
                ];
                tls = {
                  enabled = true;
                  reality = {
                    _secret = config.age.secrets.sing-box-reality.path;
                    quote = false;
                  };
                };
              }
            ];
            outbounds = [ { type = "direct"; } ];
          };
        };

        systemd.services.sing-box = {
          restartTriggers = [
            config.age.secrets.sing-box-uuid.file
            config.age.secrets.sing-box-reality.file
          ];
          serviceConfig = {
            # Both listeners use unprivileged ports; clear upstream capabilities.
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
