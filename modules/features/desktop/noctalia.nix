{
  ray.features."desktop/noctalia" = {
    nixos = {
      programs.noctalia = {
        enable = true;
        recommendedServices.enable = true;
      };

      # Niri handles lid-close through Noctalia: lock on external power,
      # lock then suspend on battery, without racing logind's lid action.
      services.logind.settings.Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchExternalPower = "ignore";
      };
    };

    home =
      {
        dotfilesRoot,
        ...
      }:
      {
        xdg.configFile."noctalia".source = dotfilesRoot + "/noctalia";
      };
  };

  ray.features."desktop/noctalia-greeter" = {
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
