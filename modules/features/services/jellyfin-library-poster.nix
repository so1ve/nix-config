{ lib, ... }:
{
  ray.features."services/jellyfin-library-poster" = {
    requires.allOf = [ "virtualisation/podman" ];
    nixos =
      _:
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
        virtualisation.quadlet = {
          volumes = lib.genAttrs (map (dir: "jellyfin-library-poster-${dir}") directories) (_: { });
          containers.jellyfin-library-poster.containerConfig = {
            Image = "docker.io/evanqu/jellyfin-library-poster@sha256:784425b269a2f6f182fd69259bfaa5d975a29481011ee56711c89d8b1a26e2e4";
            Network = [ config.virtualisation.quadlet.networks.media.ref ];
            Volume = map (
              dir: "${config.virtualisation.quadlet.volumes."jellyfin-library-poster-${dir}".ref}:/app/${dir}"
            ) directories;
          };
        };
      };
  };
}
