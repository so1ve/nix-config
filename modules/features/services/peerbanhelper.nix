{ images, lib, ... }:

{
  ray.features."services/peerbanhelper" = {
    requires.allOf = [
      "services/media"
      "services/traefik"
    ];

    options = {
      domain = lib.mkOption { type = lib.types.str; };
    };

    nixos = { settings, ... }: { config, ... }: {
      virtualisation.quadlet = {
        volumes.peerbanhelper = { };

        containers.peerbanhelper.containerConfig = {
          Image = images.peerbanhelper;
          Network = [
            config.virtualisation.quadlet.networks.media.ref
            config.virtualisation.quadlet.networks.traefik.ref
          ];
          NetworkAlias = [ "peerbanhelper" ];
          PublishPort = [ "9898:9898" ];
          Volume = [ "${config.virtualisation.quadlet.volumes.peerbanhelper.ref}:/app/data" ];
          Environment.TZ = config.time.timeZone;
          Label = {
            "traefik.enable" = "true";
            "traefik.http.routers.peerbanhelper.rule" = "Host(`${settings.domain}`)";
            "traefik.http.services.peerbanhelper.loadbalancer.server.port" = "9898";
          };
        };
      };
    };
  };
}
