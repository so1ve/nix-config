{
  ray.features."services/flaresolverr" = {
    requires.allOf = [ "virtualisation/podman" ];
    nixos = _: { config, ... }: {
      virtualisation.quadlet.containers.flaresolverr.containerConfig = {
        Image = "docker.io/flaresolverr/flaresolverr@sha256:c80ae007ce2ccdcd217a12426e4f039ef763ff90738c808d38810c3e59323767";
        Network = [ config.virtualisation.quadlet.networks.media.ref ];
        NetworkAlias = [ "flaresolverr" ];
        Environment.TZ = config.time.timeZone;
      };
    };
  };
}
