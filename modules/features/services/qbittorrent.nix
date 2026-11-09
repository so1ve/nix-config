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
    };
    nixos = { name, settings }: { config, ... }: {
      virtualisation.quadlet = {
        volumes.${name} = { };
        containers.${name}.containerConfig = {
          Image = "docker.io/linuxserver/qbittorrent@sha256:308d768672fb9e86e800a73504c439176aabe5977bcdf8b99f7561bb603d9b6e";
          Network = [
            config.virtualisation.quadlet.networks.media.ref
            config.virtualisation.quadlet.networks.traefik.ref
          ];
          NetworkAlias = [ name ];
          Volume = [
            "${config.virtualisation.quadlet.volumes.${name}.ref}:/config"
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
