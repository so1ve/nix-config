{ lib, ... }:

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
        description = "Contact email for Let's Encrypt.";
      };

      certificateDomains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "DNS names, including wildcards, to request certificates for.";
      };

      dnsChallenge = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "DNS-01 propagation settings for the network hosting Traefik.";
      };

      dynamicConfig = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Traefik file-provider configuration for backends outside Podman.";
      };
    };

    nixos =
      { settings, ... }:
      { config, pkgs, ... }:
      let
        inherit (config.virtualisation.quadlet) containers networks volumes;
        dynamicConfig = (pkgs.formats.yaml { }).generate "traefik-dynamic.yaml" settings.dynamicConfig;
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
                http.tls = {
                  certResolver = "letsencrypt";
                  domains = map (domain: {
                    main = domain;
                  }) settings.certificateDomains;
                };
              };
            };
            providers = {
              docker = {
                endpoint = "unix:///var/run/docker.sock";
                exposedByDefault = false;
                network = networks.traefik.podmanName;
              };
              file.filename = "/etc/traefik/dynamic.yaml";
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
        networking.firewall.interfaces.br-traefik = {
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };

        virtualisation.quadlet = {
          volumes.traefik = { };
          networks.traefik.networkConfig = {
            NetworkName = "traefik";
            InterfaceName = "br-traefik";
            IPv6 = true;
          };

          containers.traefik = {
            unitConfig = {
              Requires = [ "podman.socket" ];
              After = [ "podman.socket" ];
            };
            containerConfig = {
              Image = "docker.io/library/traefik:v3.7.17";
              Network = [ networks.traefik.ref ];
              PublishPort = lib.unique [
                "80:80"
                "443:443"
                "${toString settings.httpsPort}:443"
              ];
              Volume = [
                "${staticConfig}:/etc/traefik/traefik.json:ro"
                "${dynamicConfig}:/etc/traefik/dynamic.yaml:ro"
                "${volumes.traefik.ref}:/data"
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
