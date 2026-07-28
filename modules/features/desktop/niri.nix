{
  ray.features."desktop/niri" = {
    nixos =
      { pkgs, ... }:
      {
        environment.sessionVariables.NIXOS_OZONE_WL = "1";

        programs.niri = {
          enable = true;

          # nixos-unstable 624af665 ships libdisplay-info 0.4, but Niri 26.04
          # requires a version below 0.4. Remove this after c088236 reaches
          # the channel.
          package = pkgs.niri.override {
            libdisplay-info = pkgs.libdisplay-info_0_2;
          };
        };
        services.displayManager.defaultSession = "niri";

        # Niri automatically starts xwayland-satellite when it is on PATH.
        environment.systemPackages = [ pkgs.xwayland-satellite ];
      };

    home =
      {
        config,
        mkDotfilesSymlink,
        ...
      }:
      {
        xdg.configFile."niri".source = mkDotfilesSymlink {
          inherit config;
          name = "niri";
        };
      };
  };
}
