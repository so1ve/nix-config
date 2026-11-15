{ images, ... }:

{
  ray.features."services/cross-seed" = {
    requires.allOf = [ "services/media" ];

    nixos = _: { config, ... }: {
      virtualisation.quadlet = {
        volumes.cross-seed = { };

        containers.cross-seed.containerConfig = {
          Image = images.cross-seed;
          User = "1000:1000";
          Network = [ config.virtualisation.quadlet.networks.media.ref ];
          NetworkAlias = [ "cross-seed" ];
          PublishPort = [ "2468:2468" ];
          Volume = [ "${config.virtualisation.quadlet.volumes.cross-seed.ref}:/config:U" ];
          Exec = "daemon";
        };
      };
    };
  };
}
