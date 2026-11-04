{ lib, ... }:

{
  ray.features."services/cinny" = {
    requires.allOf = [
      "virtualisation/podman"
      "services/cloudflared"
      "services/matrix"
    ];

    options = {
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start the Cinny Matrix web client automatically.";
      };

      homeserver = lib.mkOption {
        type = lib.types.str;
        description = "Public Matrix homeserver hostname.";
      };
    };

    nixos =
      settings:
      {
        config,
        pkgs,
        ...
      }:
      let
        inherit (config.virtualisation.quadlet) containers networks;
        clientConfig = pkgs.writeText "cinny-config.json" (
          builtins.toJSON {
            defaultHomeserver = 0;
            homeserverList = [ settings.homeserver ];
            allowCustomHomeservers = false;
            hashRouter = {
              enabled = false;
              basename = "/";
            };
          }
        );
      in
      {
        virtualisation.quadlet.containers.cinny = {
          inherit (settings) autoStart;
          unitConfig = {
            Requires = [
              containers.cloudflared.ref
              containers.tuwunel.ref
            ];
            After = [
              containers.cloudflared.ref
              containers.tuwunel.ref
            ];
          };
          serviceConfig = {
            Restart = "always";
            TimeoutStartSec = "5min";
          };
          containerConfig = {
            ContainerName = "cinny";
            Image = "ghcr.io/cinnyapp/cinny:latest";
            Network = [ networks.cloudflared.ref ];
            NetworkAlias = [ "cinny" ];
            NoNewPrivileges = true;
            DropCapability = [ "ALL" ];
            Volume = [ "${clientConfig}:/app/config.json:ro" ];
          };
        };
      };
  };
}
