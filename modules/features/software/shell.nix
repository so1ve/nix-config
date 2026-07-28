{
  ray.features."software/shell" = {
    nixos = {
      programs.fish.enable = true;
    };

    home =
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
              alien = "nix run github:thiagokokada/nix-alien#nix-alien --";
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
}
