{
  ray.features."software/winboat" = {
    nixos =
      { username, ... }:
      {
        systemd.tmpfiles.rules = [
          "d /var/lib/containers/${username}/winboat 0700 ${username} users - -"
          # NOCOW
          "h /var/lib/containers/${username}/winboat - - - - +C"
        ];
      };

    home =
      { inputs, pkgs, ... }:
      {
        home.packages = [ inputs.so1ve.packages.${pkgs.stdenv.hostPlatform.system}.winboat ];
      };
  };
}
