{ lib, ... }:
{
  ray.features."services/emby" = {
    requires.allOf = [
      "virtualisation/podman"
      "services/traefik"
    ];
    options.domain = lib.mkOption { type = lib.types.str; };
    nixos = { settings, ... }: { config, ... }: {
      virtualisation.quadlet = {
        volumes.emby = { };
        containers.emby.containerConfig = {
          Image = "docker.io/amilys/embyserver:beta";
          Network = [ "host" ];
          AddDevice = [ "/dev/dri" ];
          Volume = [
            "${config.virtualisation.quadlet.volumes.emby.ref}:/config"
          ];
          Environment = {
            UID = toString config.users.users.media.uid;
            GID = toString config.users.groups.media.gid;
            GIDLIST = lib.concatMapStringsSep "," toString [
              config.users.groups.render.gid
              config.users.groups.video.gid
            ];
            TZ = config.time.timeZone;
          };
          Label = {
            "traefik.enable" = "true";
            "traefik.http.routers.emby.rule" = "Host(`${settings.domain}`)";
            "traefik.http.services.emby.loadbalancer.server.port" = "8096";
          };
        };
      };
    };
  };
}
