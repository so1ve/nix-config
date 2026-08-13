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

              function __fish_set_tmux_pane_state --argument-names state
                set -q TMUX_PANE; and command tmux set-option -pt "$TMUX_PANE" @pane-is-fish $state 2>/dev/null
              end

              function __fish_tmux_preexec --on-event fish_preexec; __fish_set_tmux_pane_state 0; end
              function __fish_tmux_postexec --on-event fish_postexec; __fish_set_tmux_pane_state 1; end
              function __fish_tmux_prompt --on-event fish_prompt; __fish_set_tmux_pane_state 1; end
              __fish_set_tmux_pane_state 0

              function __fish_complete_or_navigate_tmux --argument-names direction input_function
                if commandline --paging-mode; or not set -q TMUX
                  commandline -f $input_function
                else
                  command tmux select-pane -$direction
                end
              end

              bind ctrl-h '__fish_complete_or_navigate_tmux L backward-char'
              bind ctrl-j '__fish_complete_or_navigate_tmux D down-line'
              bind ctrl-k '__fish_complete_or_navigate_tmux U up-line'
              bind ctrl-l '__fish_complete_or_navigate_tmux R forward-char'
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
