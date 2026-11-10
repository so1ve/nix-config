{
  ray.features."virtualisation/podman" = {
    nixos =
      _:
      {
        inputs,
        pkgs,
        username,
        ...
      }:
      {
        imports = [ inputs.quadlet-nix.nixosModules.default ];

        virtualisation.quadlet.enable = true;

        virtualisation.podman = {
          enable = true;
          dockerCompat = true;

          defaultNetwork.settings.dns_enabled = true;

          extraPackages = [ pkgs.docker-compose ];
        };

        virtualisation.containers = {
          containersConf.settings.engine.compose_warning_logs = false;
          registries.settings.unqualified-search-registries = [
            "docker.io"
          ];
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/containers/${username} 0700 ${username} users - -"
          "d /var/lib/containers/${username}/storage 0700 ${username} users - -"
        ];
      };

    home =
      _:
      { username, ... }:
      {
        xdg.configFile."containers/storage.conf".text = ''
          [storage]
          driver = "overlay"
          graphroot = "/var/lib/containers/${username}/storage"
        '';
      };
  };
}
