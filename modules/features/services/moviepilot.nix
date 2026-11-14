{ images, lib, ... }:

{
  ray.features."services/moviepilot" = {
    requires.allOf = [
      "security/agenix"
      "services/media"
      "services/traefik"
    ];

    options = {
      domain = lib.mkOption { type = lib.types.str; };

      mediaRoot = lib.mkOption {
        type = lib.types.str;
        description = "Host media and download directory mounted at /data.";
      };
    };

    nixos =
      { settings, ... }:
      { config, ... }:
      let
        inherit (config.virtualisation.quadlet) containers volumes;
      in
      {
        virtualisation.quadlet = {
          volumes = {
            moviepilot-config = { };
            moviepilot-browser = { };
          };

          containers.moviepilot = {
            unitConfig = {
              Requires = [ "podman.socket" ];
              After = [ "podman.socket" ];
            };
            containerConfig = {
              Image = images.moviepilot;
              Network = [
                config.virtualisation.quadlet.networks.media.ref
                config.virtualisation.quadlet.networks.traefik.ref
              ];
              NetworkAlias = [ "moviepilot" ];
              PublishPort = [ "2000:3000" ];
              Volume = [
                "${volumes.moviepilot-config.ref}:/config"
                "${volumes.moviepilot-browser.ref}:/moviepilot/.cloakbrowser"
                # MoviePilot checks this marker before persisting plugin code.
                "/dev/null:/.dockerenv:ro"
                "/run/podman/podman.sock:/var/run/docker.sock:ro"
                "${settings.mediaRoot}:/data"
              ];
              Environment = {
                PUID = toString config.users.users.media.uid;
                PGID = toString config.users.groups.media.gid;
                TZ = config.time.timeZone;
                MOVIEPILOT_AUTO_UPDATE = "false";
              };
              EnvironmentFile = [ config.age.secrets.moviepilot-env.path ];
              GroupAdd = [ (toString config.users.groups.podman.gid) ];
              HealthCmd = "curl -fsS http://127.0.0.1:3001/health/ready";
              Label = {
                "traefik.enable" = "true";
                "traefik.http.routers.moviepilot.rule" = "Host(`${settings.domain}`)";
                "traefik.http.services.moviepilot.loadbalancer.server.port" = "3000";
              };
            };
          };
        };

        systemd.services.${containers.moviepilot.serviceName}.restartTriggers = [
          config.age.secrets.moviepilot-env.file
        ];
      };
  };
}
