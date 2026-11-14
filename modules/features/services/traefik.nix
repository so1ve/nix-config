{ images, lib, ... }:

{
  ray.features."services/traefik" = {
    requires.allOf = [
      "security/agenix"
      "virtualisation/podman"
    ];

    options = {
      httpsPort = lib.mkOption {
        type = lib.types.port;
        default = 443;
        description = "Public HTTPS port, also used by the HTTP redirect.";
      };

      acmeEmail = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Optional contact email for the ACME account.";
      };

      dnsChallenge = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "DNS-01 propagation settings for the network hosting Traefik.";
      };

      dnsProxy = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
        description = "Optional native dnsproxy settings for ACME DNS propagation checks.";
      };
    };

    nixos =
      { settings, ... }:
      { config, pkgs, ... }:
      let
        inherit (config.virtualisation.quadlet) containers networks volumes;
        dnsProxyEnabled = settings.dnsProxy != null;
        staticConfig = pkgs.writeText "traefik.json" (
          builtins.toJSON {
            entryPoints = {
              web = {
                address = ":80";
                http.aliasHeadersStrategy = "delete";
                http.redirections.entryPoint = {
                  to = ":${toString settings.httpsPort}";
                  scheme = "https";
                  permanent = true;
                };
              };
              websecure = {
                address = ":443";
                asDefault = true;
                http.aliasHeadersStrategy = "delete";
                http.tls.certResolver = "letsencrypt";
              };
            };
            providers = {
              docker = {
                endpoint = "unix:///var/run/docker.sock";
                exposedByDefault = false;
                network = networks.traefik.podmanName;
              };
            };
            certificatesResolvers.letsencrypt.acme = {
              email = settings.acmeEmail;
              storage = "/data/acme.json";
              dnsChallenge = {
                provider = "cloudflare";
              }
              // settings.dnsChallenge;
            };
            log.level = "WARN";
            global = {
              checkNewVersion = false;
              sendAnonymousUsage = false;
            };
          }
        );
      in
      {
        services.dnsproxy = lib.mkIf dnsProxyEnabled {
          enable = true;
          settings = {
            listen-addrs = [ "0.0.0.0" ];
            listen-ports = [ 5353 ];
          }
          // settings.dnsProxy;
        };

        networking.firewall.interfaces.br-traefik = {
          allowedTCPPorts = [
            53
          ]
          ++ lib.optionals dnsProxyEnabled config.services.dnsproxy.settings.listen-ports;
          allowedUDPPorts = [
            53
          ]
          ++ lib.optionals dnsProxyEnabled config.services.dnsproxy.settings.listen-ports;
        };

        virtualisation.quadlet = {
          volumes.traefik-acme = { };

          networks.traefik.networkConfig = {
            NetworkName = "traefik";
            InterfaceName = "br-traefik";
            IPv6 = true;
          };

          containers.traefik = {
            unitConfig = {
              Requires = [ "podman.socket" ];
              Wants = lib.optional dnsProxyEnabled "dnsproxy.service";
              After = [ "podman.socket" ] ++ lib.optional dnsProxyEnabled "dnsproxy.service";
            };
            containerConfig = {
              Image = images.traefik;
              Network = [ networks.traefik.ref ];
              PublishPort = lib.unique [
                "0.0.0.0:80:80"
                "[::]:80:80"
                "0.0.0.0:443:443"
                "[::]:443:443"
                "0.0.0.0:${toString settings.httpsPort}:443"
                "[::]:${toString settings.httpsPort}:443"
              ];
              Volume = [
                "${staticConfig}:/etc/traefik/traefik.json:ro"
                "${volumes.traefik-acme.ref}:/data"
                "/run/podman/podman.sock:/var/run/docker.sock:ro"
              ];
              EnvironmentFile = [ config.age.secrets.cloudflare-dns-env.path ];
              Exec = "--configFile=/etc/traefik/traefik.json";
              NoNewPrivileges = true;
              DropCapability = [ "ALL" ];
              AddCapability = [ "NET_BIND_SERVICE" ];
              ReadOnly = true;
            };
          };
        };

        systemd.services.${containers.traefik.serviceName}.restartTriggers = [
          config.age.secrets.cloudflare-dns-env.file
        ];
      };
  };
}
