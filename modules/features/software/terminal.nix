{
  ray.features = {
    "software/ghostty" = {
      home =
        { inputs, pkgs, ... }:
        let
          cursorShader = pkgs.writeText "ghostty-cursor-warp-long.glsl" (
            builtins.replaceStrings
              [
                "const float DURATION = 0.2;"
                "const float TRAIL_SIZE = 0.8;"
                "const float THRESHOLD_MIN_DISTANCE = 1.5;"
              ]
              [
                "const float DURATION = 0.4;"
                "const float TRAIL_SIZE = 0.95;"
                "const float THRESHOLD_MIN_DISTANCE = 0.5;"
              ]
              (builtins.readFile "${inputs.ghostty-cursor-shaders}/cursor_warp.glsl")
          );
        in
        {
          programs.ghostty = {
            enable = true;
            settings = {
              adjust-cursor-thickness = "300%";
              background = "000000";
              background-opacity = 0.9;
              background-opacity-cells = true;
              confirm-close-surface = false;
              custom-shader = "${cursorShader}";
              custom-shader-animation = true;
              font-family = [
                "R Maple Mono NF CN"
                "Unifont"
              ];
              font-size = 11;
              theme = "Kitty Default";
              window-decoration = "none";
              window-show-tab-bar = "never";
            };
          };
        };
    };

    "software/kitty" = {
      home = {
        programs.kitty = {
          enable = true;
          keybindings = {
            "ctrl+shift+h" = "";
            "ctrl+shift+l" = "";
            "ctrl+shift+p" = "show_scrollback";
          };
          settings = {
            background_opacity = "0.9";
            confirm_os_window_close = 0;
            cursor_trail = 3;
            font_family = "R Maple Mono NF CN";
            font_size = 11;
            linux_display_server = "wayland";
            scrollback_pager = "nvim --cmd 'set eventignore=FileType' +'nnoremap q ZQ' +'call nvim_open_term(0, {})' +'set nomodified nolist' +'$' -";
          };
        };
      };
    };

    "defaults/terminal/kitty" = {
      requires.allOf = [ "software/kitty" ];
      home.home.sessionVariables.TERMINAL = "kitty";
    };

    "defaults/terminal/ghostty" = {
      requires.allOf = [ "software/ghostty" ];
      home.home.sessionVariables.TERMINAL = "ghostty";
    };

    "software/herdr" = {
      home =
        {
          config,
          featureEnabled,
          inputs,
          lib,
          mkDotfilesSymlink,
          pkgs,
          ...
        }:
        let
          herdr = inputs.so1ve.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
          herdrSkill = pkgs.runCommand "herdr-skill-${herdr.version}" { } ''
            ${herdr}/bin/herdr --skill > "$out"
          '';
        in
        {
          home.packages = [
            herdr
            pkgs.jq
            pkgs.python3 # for herdr's codex integration (requires python runtime)
          ];

          home.file.".agents/skills/herdr/SKILL.md".source = herdrSkill;

          programs =
            lib.optionalAttrs (featureEnabled "software/shell") {
              fish.interactiveShellInit = ''
                if set -q HERDR_ENV
                  source ${inputs.herdr-automatic-rename}/shell/hook.fish
                else if set -q TERM_PROGRAM; and test "$TERM_PROGRAM" = WezTerm
                  ${herdr}/bin/herdr
                end
              '';
            }
            // lib.optionalAttrs (featureEnabled "software/kitty") {
              kitty.settings.shell = lib.getExe herdr;
            }
            // lib.optionalAttrs (featureEnabled "software/ghostty") {
              ghostty.settings.command = lib.getExe herdr;
            };

          xdg.configFile = {
            "herdr/config.toml".source = mkDotfilesSymlink {
              inherit config;
              name = "herdr/config.toml";
            };
            "herdr-automatic-rename/config.sh".text = ''
              AUTO_INDEX=0
              AGENT_TITLES=0
            '';
          };

          home.activation.configureHerdr = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            (
              herdr_server_status="$(${herdr}/bin/herdr status server --json)"
              if ${lib.getExe pkgs.jq} -e '.running and (.compatible == false)' <<< "$herdr_server_status" >/dev/null; then
                # A missing socket makes plugin link use Herdr's locked local registry.
                herdr_socket_dir="$(${pkgs.coreutils}/bin/mktemp -d)"
                trap '${pkgs.coreutils}/bin/rmdir "$herdr_socket_dir"' EXIT
                export HERDR_SOCKET_PATH="$herdr_socket_dir/herdr.sock"
                echo "Herdr protocol mismatch: configuring plugins offline; restart Herdr when existing panes can be closed."
              fi

              run ${herdr}/bin/herdr plugin link ${inputs.herdr-automatic-rename}
              run ${herdr}/bin/herdr plugin link ${inputs.smart-splits-nvim}

              ${lib.optionalString (featureEnabled "software/codex") ''
                run ${herdr}/bin/herdr integration install codex
              ''}

              ${lib.optionalString (featureEnabled "software/pi") ''
                run ${herdr}/bin/herdr integration install pi
              ''}

              ${lib.optionalString (featureEnabled "software/omp") ''
                run ${herdr}/bin/herdr integration install omp
              ''}

              if ${lib.getExe pkgs.jq} -e '.running and .compatible' <<< "$herdr_server_status" >/dev/null; then
                run ${herdr}/bin/herdr server reload-config
              fi
            )
          '';
        };
    };
  };
}
