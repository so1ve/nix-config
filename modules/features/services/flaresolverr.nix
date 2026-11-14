{ images, ... }:

{
  ray.features."services/flaresolverr" = {
    requires.allOf = [ "services/media" ];

    nixos = _: { config, ... }: {
      virtualisation.quadlet.containers.flaresolverr.containerConfig = {
        Image = images.flaresolverr;
        Network = [ config.virtualisation.quadlet.networks.media.ref ];
        NetworkAlias = [ "flaresolverr" ];
        PublishPort = [ "8191:8191" ];
        Environment.TZ = config.time.timeZone;
      };
    };
  };
}
