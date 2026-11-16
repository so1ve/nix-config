{ images, lib, ... }:

let
  mkTraefikHttpsLabels = import ../../../lib/mk-traefik-https-labels.nix;
in
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
            Image = images.vaultwarden;
            Network = [ config.virtualisation.quadlet.networks.traefik.ref ];
            PublishPort = [ "8222:80" ];
            Volume = [ "${config.virtualisation.quadlet.volumes.vaultwarden.ref}:/data" ];
            Environment.SIGNUPS_ALLOWED = "false";
            Label = mkTraefikHttpsLabels {
              name = "vaultwarden";
              inherit (settings) domain;
              port = 80;
            };
          };
        };
      };
  };
}
