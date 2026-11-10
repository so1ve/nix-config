{ lib, ... }:

{
  ray.features."services/qbittorrent" = {
    multiple = true;

    requires.allOf = [
      "virtualisation/podman"
      "services/traefik"
    ];

    options = {
      domain = lib.mkOption { type = lib.types.str; };

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
      virtualisation.quadlet = {
        volumes = {
          ${name} = { };
          vuetorrent = { };
        };

        containers.${name}.containerConfig = {
          Image = "docker.io/linuxserver/qbittorrent@sha256:308d768672fb9e86e800a73504c439176aabe5977bcdf8b99f7561bb603d9b6e";
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
          Label = {
            "traefik.enable" = "true";
            "traefik.http.routers.${name}.rule" = "Host(`${settings.domain}`)";
            "traefik.http.services.${name}.loadbalancer.server.port" = "9092";
            "traefik.http.services.${name}.loadbalancer.passhostheader" = "false";
          };
        };
      };
    };
  };
}
