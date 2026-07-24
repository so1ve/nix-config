{
  ray.features."desktop/niri" = {
    nixos =
      { pkgs, ... }:
      {
        environment.sessionVariables.NIXOS_OZONE_WL = "1";

        programs.niri.enable = true;
        services.displayManager.defaultSession = "niri";

        # Niri automatically starts xwayland-satellite when it is on PATH.
        environment.systemPackages = [ pkgs.xwayland-satellite ];
      };

    home =
      { mkDotfilesSymlink, ... }:
      {
        xdg.configFile."niri".source = mkDotfilesSymlink "niri";
      };
  };
}
