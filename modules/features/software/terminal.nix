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
            linux_display_server = "wayland";
            scrollback_pager = "nvim --cmd 'set eventignore=FileType' +'nnoremap q ZQ' +'call nvim_open_term(0, {})' +'set nomodified nolist' +'$' -";
          };
        };

        home.sessionVariables.TERMINAL = "kitty";
      };
    };

    "software/herdr" = {
      home =
        {
          config,
          enabledFeatures,
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

          programs.fish.interactiveShellInit = ''
            if set -q HERDR_ENV
              source ${inputs.herdr-automatic-rename}/shell/hook.fish
            else if set -q KITTY_WINDOW_ID
              ${herdr}/bin/herdr
            else if set -q TERM_PROGRAM; and test "$TERM_PROGRAM" = WezTerm
              ${herdr}/bin/herdr
            end
          '';

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
            run ${herdr}/bin/herdr plugin link ${inputs.herdr-automatic-rename}
            run ${herdr}/bin/herdr plugin link ${inputs.smart-splits-nvim}

            ${lib.optionalString (lib.elem "software/codex" enabledFeatures) ''
              run ${herdr}/bin/herdr integration install codex
            ''}

            ${lib.optionalString (lib.elem "software/pi" enabledFeatures) ''
              run ${herdr}/bin/herdr integration install pi
            ''}

            if ${herdr}/bin/herdr status server >/dev/null 2>&1; then
              run ${herdr}/bin/herdr server reload-config
            fi
          '';
        };
    };
  };
}
