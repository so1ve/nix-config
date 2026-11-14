{ images, ... }:

{
  ray.features."services/prowlarr" = {
    requires.allOf = [ "services/media" ];

    nixos = _: { config, ... }: {
      virtualisation.quadlet = {
        volumes.prowlarr = { };

        containers.prowlarr.containerConfig = {
          Image = images.prowlarr;
          Network = [ config.virtualisation.quadlet.networks.media.ref ];
          NetworkAlias = [ "prowlarr" ];
          PublishPort = [ "9696:9696" ];
          Volume = [ "${config.virtualisation.quadlet.volumes.prowlarr.ref}:/config" ];
          Environment = {
            PUID = toString config.users.users.media.uid;
            PGID = toString config.users.groups.media.gid;
            TZ = config.time.timeZone;
          };
        };
      };
    };
  };
}
