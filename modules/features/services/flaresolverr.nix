{ images, lib, ... }:

{
  ray.features."services/flaresolverr" = {
    requires.allOf = [ "services/media" ];

    nixos =
      _:
      {
        config,
        featureEnabled,
        ...
      }:
      let
        defaultHostIps =
          config.virtualisation.containers.containersConf.settings.network.default_host_ips or [ ];
        probeHost = if defaultHostIps != [ ] then lib.head defaultHostIps else "127.0.0.1";
      in
      {
        virtualisation.quadlet.containers.flaresolverr.containerConfig = {
          Image = images.flaresolverr;
          Network = [ config.virtualisation.quadlet.networks.media.ref ];
          NetworkAlias = [ "flaresolverr" ];
          PublishPort = [ "8191:8191" ];
          Environment.TZ = config.time.timeZone;
        };
      }
      // lib.optionalAttrs (featureEnabled "services/uptarn-agent") {
        ray.uptarn.monitors = [
          {
            key = "flaresolverr";
            name = "FlareSolverr";
            type = "http";
            from = "agent";
            url = "http://${probeHost}:8191/health";
          }
        ];
      };
  };
}
