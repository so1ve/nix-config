{ images, lib, ... }:

{
  ray.features."services/prowlarr" = {
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
        virtualisation.quadlet = {
          volumes.prowlarr = { };

          containers.prowlarr.containerConfig = {
            Image = images.prowlarr;
            Network = [ config.virtualisation.quadlet.networks.media.ref ];
            NetworkAlias = [ "prowlarr" ];
            PublishPort = [ "9696:9696" ];
            Volume = [ "${config.virtualisation.quadlet.volumes.prowlarr.ref}:/config" ];
            Environment = {
              PUID = "1000";
              PGID = "1000";
              TZ = config.time.timeZone;
            };
          };
        };
      }
      // lib.optionalAttrs (featureEnabled "services/uptarn-agent") {
        ray.uptarn.monitors = [
          {
            key = "prowlarr";
            name = "Prowlarr";
            type = "http";
            from = "agent";
            url = "http://${probeHost}:9696/ping";
          }
        ];
      };
  };
}
