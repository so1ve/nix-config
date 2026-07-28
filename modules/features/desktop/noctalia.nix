{
  ray.features."desktop/noctalia" = {
    nixos =
      { inputs, ... }:
      {
        imports = [ inputs.noctalia.nixosModules.default ];

        programs.noctalia = {
          enable = true;
          recommendedServices.enable = true;
        };

        # Niri routes lid-close through Noctalia so the session is locked
        # before suspend instead of racing logind's built-in lid action.
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
