{
  ray.features."desktop/niri" = {
    nixos =
      { inputs, pkgs, ... }:
      let
        personalPackages = import inputs.so1ve { inherit pkgs; };
      in
      {
        environment.sessionVariables.NIXOS_OZONE_WL = "1";

        # FIXME: Switch back to pkgs.niri after the upstream PR is merged:
        # https://github.com/niri-wm/niri/pull/3305 or https://github.com/niri-wm/niri/pull/4147
        programs.niri = {
          enable = true;
          package = personalPackages.niri;
        };
        services.displayManager.defaultSession = "niri";

        # GNOME/GTK portal file choosers use GVfs to discover removable media.
        services = {
          gvfs.enable = true;
          udisks2.enable = true;
        };

        environment.systemPackages = [
          # FIXME: Switch back to pkgs.xwayland-satellite after the upstream PR is merged:
          # https://github.com/Supreeeme/xwayland-satellite/pull/477
          personalPackages.xwayland-satellite
        ];
      };

    home =
      {
        config,
        inputs,
        mkDotfilesSymlink,
        mkFocusOrLaunch,
        pkgs,
        ...
      }:
      {
        home.packages = [
          (mkFocusOrLaunch pkgs)
          inputs.latchshot.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];

        xdg.configFile."niri".source = mkDotfilesSymlink {
          inherit config;
          name = "niri";
        };
      };
  };
}
