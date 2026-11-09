{ lib, ... }:
{
  ray.features."services/jellyfin-library-poster" = {
    requires.allOf = [ "virtualisation/podman" ];
    options.dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/jellyfin-library-poster";
    };
    nixos =
      { settings, ... }:
      { config, ... }:
      let
        directories = [
          "config"
          "logs"
          "myfont"
          "output"
          "poster"
        ];
      in
      {
        systemd.tmpfiles.rules = [
          "d ${settings.dataDir} 0700 root root - -"
        ]
        ++ map (dir: "d ${settings.dataDir}/${dir} 0750 media media - -") directories;
        virtualisation.quadlet.containers.jellyfin-library-poster.containerConfig = {
          Image = "docker.io/evanqu/jellyfin-library-poster@sha256:784425b269a2f6f182fd69259bfaa5d975a29481011ee56711c89d8b1a26e2e4";
          Network = [ config.virtualisation.quadlet.networks.media.ref ];
          Volume = map (dir: "${settings.dataDir}/${dir}:/app/${dir}") directories;
        };
      };
  };
}
