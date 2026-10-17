{
  ray.features."virtualisation/winboat" = {
    requires.allOf = [ "virtualisation/podman" ];

    nixos =
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
      { inputs, pkgs, ... }:
      {
        home.packages = [
          # Keep the original nixpkgs pin until guest-server stops using buildGo125Module.
          inputs.so1ve.packages.${pkgs.stdenv.hostPlatform.system}.winboat-unstable
        ];
      };
  };
}
