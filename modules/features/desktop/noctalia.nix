{
  ray.features."desktop/noctalia" = {
    requires = [ "desktop/niri" ];

    nixos =
      { pkgs, ... }:
      {
        programs.noctalia = {
          enable = true;
          recommendedServices.enable = true;
        };

        # Let Noctalia control external monitor brightness through DDC/CI.
        hardware.i2c.enable = true;
        environment.systemPackages = [ pkgs.ddcutil ];

        # Niri handles lid-close through Noctalia: lock on external power,
        # lock then suspend on battery, without racing logind's lid action.
        services.logind.settings.Login = {
          HandleLidSwitch = "ignore";
          HandleLidSwitchExternalPower = "ignore";
        };
      };

    home =
      {
        config,
        mkDotfilesSymlink,
        ...
      }:
      {
        xdg.configFile."noctalia".source = mkDotfilesSymlink {
          inherit config;
          name = "noctalia";
        };
      };
  };

  ray.features."desktop/noctalia-greeter" = {
    requires = [ "desktop/niri" ];

    nixos =
      { inputs, ... }:
      {
        imports = [ inputs.noctalia-greeter.nixosModules.default ];

        programs.noctalia-greeter = {
          enable = true;
          greeter-args = "--session niri";
        };

        security.polkit.enable = true;
        services.accounts-daemon.enable = true;
      };
  };
}
