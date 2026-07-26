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
      home = {
        programs.tmux = {
          enable = true;
          baseIndex = 1;
          escapeTime = 0;
          historyLimit = 100000;
          keyMode = "vi";
          mouse = true;
          terminal = "tmux-256color";
          extraConfig = ''
            set -as terminal-features ",xterm-kitty:RGB"
            set -g focus-events on
            set -g renumber-windows on
            set -g set-clipboard on
          '';
        };
      };
    };
  };
}
