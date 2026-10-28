{
  ray.features."desktop/noctalia" = {
    requires.anyOf = [
      "desktop/hyprland"
      "desktop/niri"
    ];

    nixos =
      _:
      { pkgs, ... }:
      {
        programs.noctalia = {
          enable = true;
          recommendedServices.enable = true;
        };

        # Let Noctalia control external monitor brightness through DDC/CI.
        hardware.i2c.enable = true;
        environment.systemPackages = [ pkgs.ddcutil ];

        # Noctalia handles lid-close: lock on external power,
        # lock then suspend on battery, without racing logind's lid action.
        services.logind.settings.Login = {
          HandleLidSwitch = "ignore";
          HandleLidSwitchExternalPower = "ignore";
        };
      };

    home =
      _:
      { mkDotfilesSource, ... }:
      {
        xdg.configFile."noctalia".source = mkDotfilesSource "noctalia";
      };
  };

  ray.features."desktop/noctalia-greeter" = {
    requires.allOf = [ "desktop/niri" ];

    nixos =
      _:
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
