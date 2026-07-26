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
        { pkgs, ... }:
        {
          programs.kitty = {
            enable = true;
            settings = {
              cursor_trail = 3;
              font_family = "R Maple Mono NF CN";
              hide_window_decorations = "yes";
              linux_display_server = "wayland";
              shell = "${pkgs.tmux}/bin/tmux new-session -A -s main";
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

          xdg.configFile."tmux/tmux.conf".source = mkDotfilesSymlink {
            inherit config;
            name = "tmux/tmux.conf";
          };
        };
    };
  };
}
