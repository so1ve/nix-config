{ lib, ... }:
{
  ray.features."services/moviepilot" = {
    requires.allOf = [
      "security/agenix"
      "virtualisation/podman"
      "services/traefik"
    ];
    options = {
      domain = lib.mkOption { type = lib.types.str; };
      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
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
              Image = "docker.io/jxxghp/moviepilot-v3@sha256:c9ab74b94427a18134b9c5e8d6fa0c186f6740c033029b69eceda0a07f4021af";
              Network = [
                config.virtualisation.quadlet.networks.media.ref
                config.virtualisation.quadlet.networks.traefik.ref
              ];
              NetworkAlias = [ "moviepilot" ];
              Volume = [
                "${volumes.moviepilot-config.ref}:/config"
                "${volumes.moviepilot-browser.ref}:/moviepilot/.cloakbrowser"
                "/run/podman/podman.sock:/var/run/docker.sock:ro"
              ];
              Environment = {
                PUID = toString config.users.users.media.uid;
                PGID = toString config.users.groups.media.gid;
                TZ = config.time.timeZone;
                MOVIEPILOT_AUTO_UPDATE = "false";
              }
              // settings.environment;
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
