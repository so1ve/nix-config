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
      { inputs, pkgs, ... }:
      {
        home.packages = [ (import inputs.so1ve { inherit pkgs; }).winboat-unstable ];
      };
  };
}
