{
  ray.features."desktop/niri" = {
    nixos =
      { pkgs, ... }:
      {
        environment.sessionVariables.NIXOS_OZONE_WL = "1";

        programs.niri.enable = true;
        services.displayManager.defaultSession = "niri";

        # GNOME/GTK portal file choosers use GVfs to discover removable media.
        services = {
          gvfs.enable = true;
          udisks2.enable = true;
        };

        environment.systemPackages = [ pkgs.xwayland-satellite ];
      };

    home =
      {
        config,
        mkDotfilesSymlink,
        mkFocusOrLaunch,
        pkgs,
        ...
      }:
      {
        home.packages = [ (mkFocusOrLaunch pkgs) ];

        xdg.configFile."niri".source = mkDotfilesSymlink {
          inherit config;
          name = "niri";
        };
      };
  };
}
