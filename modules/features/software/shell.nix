{
  ray.features."software/shell" = {
    nixos = _: {
      programs.fish.enable = true;
    };

    home =
      _:
      {
        config,
        mkDotfilesSymlink,
        ...
      }:
      let
        cliLocale = "en_US.UTF-8";
      in
      {
        programs = {
          bash = {
            enable = true;
            initExtra = ''
              export LANG=${cliLocale}
              export LANGUAGE=en_US
            '';
          };

          fish = {
            enable = true;
            shellAbbrs = {
              nd = "nix develop -c fish";
              sr = "steam-run";
            };
            interactiveShellInit = ''
              set -gx LANG ${cliLocale}
              set -gx LANGUAGE en_US
              set -g fish_greeting
            '';
          };

          starship.enable = true;
          zoxide.enable = true;
        };

        xdg.configFile."starship.toml".source = mkDotfilesSymlink {
          inherit config;
          name = "starship.toml";
        };
      };
  };

  ray.features."defaults/shell/fish" = {
    requires.allOf = [
      "software/shell"
      "users/ray"
    ];

    nixos =
      _:
      { config, username, ... }:
      {
        users.users.${username}.shell = config.programs.fish.package;
      };
  };
}
