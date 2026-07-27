{
  ray.features."virtualisation/podman" = {
    nixos =
      { pkgs, ... }:
      {
        virtualisation.podman = {
          enable = true;
          dockerCompat = true;

          defaultNetwork.settings.dns_enabled = true;

          # `podman compose` delegates Compose parsing to an external
          # provider and connects it to the rootless Podman socket.
          extraPackages = [ pkgs.docker-compose ];
        };
      };
  };
}
