{
  ray.features."virtualisation/winboat" = {
    requires.allOf = [ "virtualisation/podman" ];

    nixos =
      _:
      { username, ... }:
      {
        systemd.tmpfiles.rules = [
          "d /var/lib/containers/${username}/winboat 0700 ${username} users - -"
          # NOCOW
          "h /var/lib/containers/${username}/winboat - - - - +C"
        ];

        users.users.${username}.extraGroups = [ "kvm" ];
      };

    home =
      _:
      { pkgs, ... }:
      {
        home.packages = [ pkgs.so1ve.winboat-unstable ];
      };
  };
}
