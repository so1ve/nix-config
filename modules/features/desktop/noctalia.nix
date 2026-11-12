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
      {
        # featureEnabled,
        mkDotfilesSource,
        # pkgs,
        ...
      }:
      {
        xdg.configFile."noctalia".source =
          # if featureEnabled "desktop/we-layerd" || featureEnabled "desktop/waywallen" then
          #   pkgs.linkFarm "noctalia-config" {
          #     assets = mkDotfilesSource "noctalia/assets";
          #     "config.toml" = mkDotfilesSource "noctalia/config.toml";
          #     "external-wallpaper.toml" = pkgs.writeText "external-wallpaper.toml" ''
          #       [wallpaper]
          #       enabled = false
          #     '';
          #   }
          # else
          mkDotfilesSource "noctalia";
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
