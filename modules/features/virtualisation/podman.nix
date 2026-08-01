{
  ray.features."virtualisation/podman" = {
    nixos =
      { pkgs, ... }:
      {
        virtualisation.podman = {
          enable = true;
          dockerCompat = true;

          defaultNetwork.settings.dns_enabled = true;

          extraPackages = [ pkgs.podman-compose ];
        };
      };
  };
}
