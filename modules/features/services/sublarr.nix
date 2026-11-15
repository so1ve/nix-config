{ images, lib, ... }:

{
  ray.features."services/sublarr" = {
    requires.allOf = [ "services/media" ];

    options = {
      mediaRoot = lib.mkOption {
        type = lib.types.str;
        description = "Host media directory mounted at /video.";
      };
    };

    nixos = { settings, ... }: { config, ... }: {
      virtualisation.quadlet = {
        volumes.sublarr = { };

        containers.sublarr.containerConfig = {
          Image = images.sublarr;
          Network = [ config.virtualisation.quadlet.networks.media.ref ];
          NetworkAlias = [ "sublarr" ];
          PublishPort = [ "5765:5765" ];
          Volume = [
            "${config.virtualisation.quadlet.volumes.sublarr.ref}:/config"
            "${settings.mediaRoot}:/video"
          ];
          Environment = {
            PUID = toString config.users.users.media.uid;
            PGID = toString config.users.groups.media.gid;
            TZ = config.time.timeZone;
            SUBLARR_MEDIA_PATH = "/video";
            SUBLARR_STATS_ENDPOINT = "";
          };
        };
      };
    };
  };
}
