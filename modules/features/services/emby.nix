{ lib, ... }:
{
  ray.features."services/emby" = {
    requires.allOf = [ "virtualisation/podman" ];
    nixos = _: { config, ... }: {
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
        };
      };
    };
  };
}
