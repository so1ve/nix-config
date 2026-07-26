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
      home =
        { ... }:
        {
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
              ${pkgs.tmux}/bin/tmux new-session -A -s main
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
