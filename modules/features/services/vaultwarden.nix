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

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/vaultwarden";
        description = "Local directory containing the Vaultwarden database and attachments.";
      };

    };

    nixos =
      { settings, ... }:
      { config, ... }:
      {
        systemd.tmpfiles.rules = [ "d ${settings.dataDir} 0700 root root - -" ];

        virtualisation.quadlet.containers.vaultwarden.containerConfig = {
          Image = "docker.io/vaultwarden/server:1.37.5";
          Network = [ config.virtualisation.quadlet.networks.traefik.ref ];
          Volume = [ "${settings.dataDir}:/data" ];
          Environment.SIGNUPS_ALLOWED = "false";
          Label = {
            "traefik.enable" = "true";
            "traefik.http.routers.vaultwarden.rule" = "Host(`${settings.domain}`)";
            "traefik.http.services.vaultwarden.loadbalancer.server.port" = "80";
          };
        };

      };
  };
}
