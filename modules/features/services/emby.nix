{ lib, ... }:
{
  ray.features."services/emby" = {
    requires.allOf = [ "virtualisation/podman" ];
    options.dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/emby";
    };
    nixos = { settings, ... }: { config, ... }: {
      systemd.tmpfiles.rules = [ "d ${settings.dataDir} 0750 media media - -" ];
      virtualisation.quadlet.containers.emby.containerConfig = {
        Image = "docker.io/amilys/embyserver:beta";
        Network = [ "host" ];
        AddDevice = [ "/dev/dri" ];
        Volume = [
          "${settings.dataDir}:/config"
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
}
