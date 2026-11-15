{ images, ... }:

{
  ray.features."services/peerbanhelper" = {
    requires.allOf = [ "services/media" ];

    nixos = _: { config, ... }: {
      virtualisation.quadlet = {
        volumes.peerbanhelper = { };

        containers.peerbanhelper.containerConfig = {
          Image = images.peerbanhelper;
          Network = [ config.virtualisation.quadlet.networks.media.ref ];
          NetworkAlias = [ "peerbanhelper" ];
          PublishPort = [ "9898:9898" ];
          Volume = [ "${config.virtualisation.quadlet.volumes.peerbanhelper.ref}:/app/data" ];
          Environment.TZ = config.time.timeZone;
        };
      };
    };
  };
}
