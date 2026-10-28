{ lib, ... }:

{
  ray.features."services/cloudflared" = {
    requires.allOf = [
      "security/agenix"
      "virtualisation/podman"
    ];

    options.autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start the Cloudflare Tunnel automatically.";
    };

    nixos =
      settings:
      { config, hostname, ... }:
      {
        age.secrets.cloudflared-env.file = ../../../secrets + "/${hostname}/cloudflared-env.age";

        networking.firewall.interfaces.br-cloudflared = {
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };

        virtualisation.quadlet = {
          networks.cloudflared.networkConfig = {
            NetworkName = "cloudflared";
            InterfaceName = "br-cloudflared";
            Options = [ "isolate=true" ];
          };

          containers.cloudflared = {
            inherit (settings) autoStart;
            serviceConfig = {
              Restart = "always";
              TimeoutStartSec = "5min";
            };
            containerConfig = {
              ContainerName = "cloudflared";
              Image = "docker.io/cloudflare/cloudflared:latest";
              Network = [ config.virtualisation.quadlet.networks.cloudflared.ref ];
              NoNewPrivileges = true;
              DropCapability = [ "ALL" ];
              ReadOnly = true;
              EnvironmentFile = [ config.age.secrets.cloudflared-env.path ];
              Exec = "tunnel --metrics 127.0.0.1:2000 run";
            };
          };
        };

        systemd.services.cloudflared.restartTriggers = [ config.age.secrets.cloudflared-env.file ];
      };
  };
}
