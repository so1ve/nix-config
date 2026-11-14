{ images, lib, ... }:

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
            Image = images.jellyfin-library-poster;
            Network = [ config.virtualisation.quadlet.networks.media.ref ];
            Volume = map (
              dir: "${config.virtualisation.quadlet.volumes."jellyfin-library-poster-${dir}".ref}:/app/${dir}"
            ) directories;
          };
        };
      };
  };
}
