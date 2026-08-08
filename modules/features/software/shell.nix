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
              ae = "agenix -i ~/.config/agenix/identity -e";
              nd = "nix develop -c fish";
              sr = "steam-run";
            };
            interactiveShellInit = ''
              set -gx LANG ${cliLocale}
              set -gx LANGUAGE en_US
              set -g fish_greeting

              fish_vi_key_bindings
              bind -M default H beginning-of-line
              bind -M default L end-of-line

              # Fish normally cancels an open completion pager on Escape and
              # moves the cursor left when entering Normal mode. Keep the
              # pager and cursor position so both Escape -> Tab and
              # Tab -> Escape -> j/k remain useful.
              bind -M insert -m default escape repaint-mode
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
