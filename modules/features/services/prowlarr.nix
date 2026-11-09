{ lib, ... }:
{
  ray.features."services/prowlarr" = {
    requires.allOf = [ "virtualisation/podman" ];
    options.dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/prowlarr";
    };
    nixos = { settings, ... }: { config, ... }: {
      systemd.tmpfiles.rules = [ "d ${settings.dataDir} 0750 media media - -" ];
      virtualisation.quadlet.containers.prowlarr.containerConfig = {
        Image = "docker.io/linuxserver/prowlarr@sha256:431d7efebcef466e56adaa40a7a2fa2b0e85159a037b8bf465eaadbf0cf5bedf";
        Network = [ config.virtualisation.quadlet.networks.media.ref ];
        NetworkAlias = [ "prowlarr" ];
        Volume = [ "${settings.dataDir}:/config" ];
        Environment = {
          PUID = toString config.users.users.media.uid;
          PGID = toString config.users.groups.media.gid;
          TZ = config.time.timeZone;
        };
      };
    };
  };
}
