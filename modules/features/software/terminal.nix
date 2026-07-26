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
            set -as terminal-features ",xterm-kitty:RGB:extkeys"
            set -g focus-events on
            set -g renumber-windows on
            set -g set-clipboard on

            bind-key -n C-h if -F "#{@pane-is-vim}" "send-keys C-h" "select-pane -L"
            bind-key -n C-j if -F "#{@pane-is-vim}" "send-keys C-j" "select-pane -D"
            bind-key -n C-k if -F "#{@pane-is-vim}" "send-keys C-k" "select-pane -U"
            bind-key -n C-l if -F "#{@pane-is-vim}" "send-keys C-l" "select-pane -R"

            bind-key -n C-Left if -F "#{@pane-is-vim}" "send-keys C-Left" "resize-pane -L 1"
            bind-key -n C-Down if -F "#{@pane-is-vim}" "send-keys C-Down" "resize-pane -D 1"
            bind-key -n C-Up if -F "#{@pane-is-vim}" "send-keys C-Up" "resize-pane -U 1"
            bind-key -n C-Right if -F "#{@pane-is-vim}" "send-keys C-Right" "resize-pane -R 1"
          '';
        };
      };
    };
  };
}
