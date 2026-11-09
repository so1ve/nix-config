{ lib, ... }:

{
  ray.features."services/vaultwarden" = {
    requires.allOf = [
      "virtualisation/podman"
      "services/traefik"
    ];

    options = {
      domain = lib.mkOption {
        type = lib.types.str;
        description = "Public hostname served by Vaultwarden.";
      };
    };

    nixos =
      { settings, ... }:
      { config, ... }:
      {
        virtualisation.quadlet = {
          volumes.vaultwarden = { };

          containers.vaultwarden.containerConfig = {
            Image = "docker.io/vaultwarden/server:1.37.5";
            Network = [ config.virtualisation.quadlet.networks.traefik.ref ];
            Volume = [ "${config.virtualisation.quadlet.volumes.vaultwarden.ref}:/data" ];
            Environment.SIGNUPS_ALLOWED = "false";
            Label = {
              "traefik.enable" = "true";
              "traefik.http.routers.vaultwarden.rule" = "Host(`${settings.domain}`)";
              "traefik.http.services.vaultwarden.loadbalancer.server.port" = "80";
            };
          };
        };
      };
  };
}
