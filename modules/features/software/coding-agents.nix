{
  ray.features = {
    "software/codex".home =
      {
        config,
        mkDotfilesSymlink,
        pkgs,
        ...
      }:
      {
        home.packages = [ pkgs.codex ];
        home.file.".codex/AGENTS.md".source = mkDotfilesSymlink {
          inherit config;
          name = "agents/AGENTS.md";
        };
      };

    "software/codex-desktop".home =
      {
        inputs,
        lib,
        pkgs,
        ...
      }:
      let
        linuxFeatures = [
          "appshots"
          "mcp-helper-reaper"
          "node-repl-reaper"
          "ui-tweaks"
        ];

        linuxFeaturesConfig = pkgs.writeText "codex-linux-features.json" (
          builtins.toJSON {
            enabled = linuxFeatures;
            settings."ui-tweaks".tweaks = {
              home.suggestedPrompts.enabled = false;
              modelPicker.showModelsByDefault.enabled = true;
              reasoning.keepEffortLabelsEnglish.enabled = true;
              sidebar.projectName.enabled = false;
            };
          }
        );

        upstreamDesktop =
          inputs.codex-desktop-linux.packages.${pkgs.stdenv.hostPlatform.system}.codex-desktop.override
            {
              linuxFeatureIds = linuxFeatures;
            };

        desktop = upstreamDesktop.overrideAttrs (old: {
          installPhase =
            let
              lines = lib.splitString "\n" old.installPhase;
              featureConfigLines = lib.filter (lib.hasInfix "export CODEX_LINUX_FEATURES_CONFIG=") lines;
            in
            assert builtins.length featureConfigLines == 1;
            lib.concatStringsSep "\n" (
              map (
                line:
                if lib.hasInfix "export CODEX_LINUX_FEATURES_CONFIG=" line then
                  ''export CODEX_LINUX_FEATURES_CONFIG="${linuxFeaturesConfig}"''
                else
                  line
              ) lines
            );
        });
      in
      {
        imports = [ inputs.codex-desktop-linux.homeManagerModules.default ];

        programs.codexDesktopLinux = {
          enable = true;
          package = desktop;
        };

        home.packages = [
          # AppShots needs a Wayland-capable screenshot backend.
          pkgs.grim
        ];
      };

    "software/pi".home =
      {
        config,
        mkDotfilesSymlink,
        pkgs,
        ...
      }:
      {
        # pi-workspace-history creates internal Git commits. Do not sign these
        # snapshots with the user's normal signing key.
        programs.git.includes = [
          {
            condition = "gitdir:${config.home.homeDirectory}/.pi/agent/state/workspace-history/";
            contents.commit.gpgSign = false;
          }
        ];

        programs.pi-coding-agent = {
          enable = true;
          context = mkDotfilesSymlink {
            inherit config;
            name = "agents/AGENTS.md";
          };
          extraPackages = with pkgs; [
            git
            nodejs
            pnpm
          ];
          keybindings = {
            "app.exit" = [
              "ctrl+c"
              "ctrl+d"
            ];
            # Disable pi's builtin keybinding to avoid conflict with pi-parallel-sessions
            "app.session.rename" = [ ];
          };
          settings = {
            defaultModel = "gpt-5.6-sol";
            defaultProvider = "openai-codex";
            defaultThinkingLevel = "xhigh";
            retry = {
              enabled = true;
              maxRetries = 3;
            };
            theme = "dark";
            npmCommand = [
              "pnpm"
              "--config.node-linker=hoisted"
            ];
            packages = [
              "npm:@czottmann/pi-automode"
              "npm:@ff-labs/pi-fff"
              "npm:@gotgenes/pi-subagents"
              "npm:@gotgenes/pi-subagents-worktrees"
              "npm:@juicesharp/rpiv-ask-user-question"
              "npm:@narumitw/pi-btw"
              "npm:@narumitw/pi-plan-mode"
              "npm:@narumitw/pi-usage"
              "npm:@upstash/context7-pi"
              "npm:pi-codex-goal"
              "npm:pi-draft-history"
              "npm:pi-parallel-sessions"
              "npm:pi-markdown-preview"
              "npm:pi-mcp-adapter"
              "npm:pi-nano-context"
              "npm:pi-openai-api-models-sync"
              "npm:pi-simplify"
              "npm:pi-smart-fetch"
              "npm:pi-tool-display"
              "npm:pi-web-access"
              "npm:pi-workspace-history"
              "npm:pi-wtf"
            ];
          };
        };
      };
  };
}
