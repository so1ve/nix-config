{ lib, ... }:
{
  ray.features."services/peerbanhelper" = {
    requires.allOf = [
      "virtualisation/podman"
      "services/traefik"
    ];
    options = {
      domain = lib.mkOption { type = lib.types.str; };
    };
    nixos = { settings, ... }: { config, ... }: {
      virtualisation.quadlet = {
        volumes.peerbanhelper = { };
        containers.peerbanhelper.containerConfig = {
          Image = "docker.io/ghostchu/peerbanhelper@sha256:01a8ccab4d007701ecaf9c433e934a323bddd8a1668d3484543be870de8762bf";
          Network = [
            config.virtualisation.quadlet.networks.media.ref
            config.virtualisation.quadlet.networks.traefik.ref
          ];
          NetworkAlias = [ "peerbanhelper" ];
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
