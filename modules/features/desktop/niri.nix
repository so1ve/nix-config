{
  ray.features."desktop/niri" = {
    nixos =
      { pkgs, ... }:
      {
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
