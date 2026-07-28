{
  ray.features = {
    "software/ghostty" = {
      home = {
        programs.ghostty = {
          enable = true;
          settings.font-family = "R Maple Mono NF CN";
        };
      };
    };

    "software/kitty" = {
      home = {
        programs.kitty = {
          enable = true;
          settings = {
            background_opacity = "0.92";
            cursor_trail = 3;
            font_family = "R Maple Mono NF CN";
            hide_window_decorations = "yes";
            linux_display_server = "wayland";
          };
        };

        home.sessionVariables.TERMINAL = "kitty";
      };
    };

    "software/tmux" = {
      home =
        {
          config,
          mkDotfilesSymlink,
          pkgs,
          ...
        }:
        {
          home.packages = [ pkgs.tmux ];

          programs.fish.interactiveShellInit = ''
            if set -q KITTY_WINDOW_ID; and not set -q TMUX
              if not ${pkgs.tmux}/bin/tmux has-session -t main 2>/dev/null
                if ${pkgs.tmux}/bin/tmux new-session -d -x "$COLUMNS" -y "$LINES" -s main -n workspace
                  ${pkgs.tmux}/bin/tmux split-window -h -p 70 -t main:1.1
                  ${pkgs.tmux}/bin/tmux split-window -v -p 25 -t main:1.2
                  ${pkgs.tmux}/bin/tmux new-window -t main:2 -n shell
                  ${pkgs.tmux}/bin/tmux select-window -t main:1
                  ${pkgs.tmux}/bin/tmux select-pane -t main:1.1
                end
              end

              ${pkgs.tmux}/bin/tmux attach-session -t main
            end
          '';

          xdg.configFile."tmux/tmux.conf".source = mkDotfilesSymlink {
            inherit config;
            name = "tmux/tmux.conf";
          };
        };
    };
  };
}
