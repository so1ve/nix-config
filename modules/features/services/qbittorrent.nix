{ images, lib, ... }:

let
  mkTraefikHttpsLabels = import ../../../lib/mk-traefik-https-labels.nix;
in
{
  ray.features."services/qbittorrent" = {
    multiple = true;

    requires.allOf = [
      "services/media"
      "services/traefik"
    ];

    options = {
      domain = lib.mkOption { type = lib.types.str; };

      webPort = lib.mkOption {
        type = lib.types.port;
        description = "Host port for the web interface.";
      };

      mediaRoot = lib.mkOption {
        type = lib.types.str;
        description = "Host media and download directory mounted at /data.";
      };

      lanNetwork = lib.mkOption {
        type = lib.types.str;
        description = "Name of the host's Quadlet LAN network resource.";
      };

      ipv4Address = lib.mkOption { type = lib.types.str; };

      ipv6Address = lib.mkOption { type = lib.types.str; };

      macAddress = lib.mkOption { type = lib.types.str; };
    };

    nixos = { name, settings }: { config, ... }: {
      services.traefik.staticConfigOptions.entryPoints.${name}.address = ":${toString settings.webPort}";

      virtualisation.quadlet = {
        volumes = {
          ${name} = { };
          vuetorrent = { };
        };

        containers.${name}.containerConfig = {
          Image = images.qbittorrent;
          Network = [
            "${
              config.virtualisation.quadlet.networks.${settings.lanNetwork}.ref
            }:ip=${settings.ipv4Address},ip6=${settings.ipv6Address},mac=${settings.macAddress}"
            config.virtualisation.quadlet.networks.media.ref
            config.virtualisation.quadlet.networks.traefik.ref
          ];
          Sysctl = [
            "net.ipv6.conf.eth0.autoconf=1"
            "net.ipv6.conf.eth0.accept_ra=2"
          ];
          NetworkAlias = [ name ];
          Volume = [
            "${config.virtualisation.quadlet.volumes.${name}.ref}:/config"
            "${config.virtualisation.quadlet.volumes.vuetorrent.ref}:/vuetorrent"
            "${settings.mediaRoot}:/data"
          ];
          Environment = {
            PUID = toString config.users.users.media.uid;
            PGID = toString config.users.groups.media.gid;
            TZ = config.time.timeZone;
            WEBUI_PORT = "9092";
          };
          Label =
            mkTraefikHttpsLabels {
              inherit name;
              inherit (settings) domain;
              port = 9092;
            }
            // {
              "traefik.http.routers.${name}-local.entrypoints" = name;
              "traefik.http.routers.${name}-local.rule" = "PathPrefix(`/`)";
              "traefik.http.routers.${name}-local.service" = name;
              "traefik.http.services.${name}.loadbalancer.passhostheader" = "false";
            };
        };

        containers.traefik.containerConfig.PublishPort = [
          "${toString settings.webPort}:${toString settings.webPort}"
        ];
      };
    };
  };
}
