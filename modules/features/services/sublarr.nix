{ lib, ... }:
{
  ray.features."services/sublarr" = {
    requires.allOf = [
      "virtualisation/podman"
      "services/traefik"
    ];
    options.domain = lib.mkOption { type = lib.types.str; };
    nixos = { settings, ... }: { config, ... }: {
      virtualisation.quadlet = {
        volumes.sublarr = { };
        containers.sublarr.containerConfig = {
          Image = "ghcr.io/abrechen2/sublarr:1.20.1";
          Network = [
            config.virtualisation.quadlet.networks.media.ref
            config.virtualisation.quadlet.networks.traefik.ref
          ];
          NetworkAlias = [ "sublarr" ];
          Volume = [ "${config.virtualisation.quadlet.volumes.sublarr.ref}:/config" ];
          Environment = {
            PUID = toString config.users.users.media.uid;
            PGID = toString config.users.groups.media.gid;
            TZ = config.time.timeZone;
            SUBLARR_STATS_ENDPOINT = "";
          };
          Label = {
            "traefik.enable" = "true";
            "traefik.http.routers.sublarr.rule" = "Host(`${settings.domain}`)";
            "traefik.http.services.sublarr.loadbalancer.server.port" = "5765";
          };
        };
      };
    };
  };
}
