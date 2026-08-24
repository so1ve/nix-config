{
  inputs,
  lib,
  ...
}:
let
  cloudflareSkillFiles =
    target:
    lib.mapAttrs'
      (
        name: _:
        lib.nameValuePair "${target}/${name}" {
          source = "${inputs.cloudflare-skills}/skills/${name}";
        }
      )
      (
        lib.filterAttrs (_: type: type == "directory") (
          builtins.readDir "${inputs.cloudflare-skills}/skills"
        )
      );
in
{
  ray.features = {
    "software/codex".home =
      {
        config,
        inputs,
        mkDotfilesSymlink,
        pkgs,
        ...
      }:
      {
        home = {
          packages = [ inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex ];
          file = cloudflareSkillFiles ".codex/skills" // {
            ".agents/skills/refactor-for-simplicity".source = mkDotfilesSymlink {
              inherit config;
              name = "agents/skills/refactor-for-simplicity";
            };
            ".codex/AGENTS.md".source = mkDotfilesSymlink {
              inherit config;
              name = "agents/AGENTS.md";
            };
          };
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
            enabled = upstreamDesktop.passthru.effectiveLinuxFeatureIds;
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
        home.file = cloudflareSkillFiles ".pi/agent/skills";

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
          ];
          keybindings = {
            "app.exit" = [
              "ctrl+c"
              "ctrl+d"
            ];
            # Disable pi's builtin keybinding to avoid conflict with pi-parallel-sessions
            "app.session.rename" = [ ];
            "tui.editor.historyNext" = [ "ctrl+n" ];
            "tui.editor.historyPrevious" = [ "ctrl+p" ];
          };
          settings = {
            defaultModel = "gpt-5.6-sol";
            defaultProvider = "openai-codex";
            defaultThinkingLevel = "max";
            retry = {
              enabled = true;
              maxRetries = 3;
            };
            theme = "dark";
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
              "npm:pi-workspace-sessions"
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

    "software/dsh" = {
      requires = [ "security/agenix" ];

      home =
        {
          config,
          inputs,
          pkgs,
          ...
        }:
        let
          deepseekApiKey = config.age.secrets.deepseek-api-key.path;
          deepseekHarness =
            inputs.so1ve.packages.${pkgs.stdenv.hostPlatform.system}.deepseek-harness;
          dsh = pkgs.writeShellApplication {
            name = "dsh";
            text = ''
              DEEPSEEK_API_KEY="$(< "${deepseekApiKey}")"
              export DEEPSEEK_API_KEY
              exec ${deepseekHarness}/bin/dsh "$@"
            '';
          };
        in
        {
          imports = [ inputs.so1ve.homeModules.deepseek-harness ];

          age.secrets.deepseek-api-key.file = "${inputs.self}/secrets/deepseek-api-key.age";

          programs.deepseek-harness = {
            enable = true;
            package = dsh;
            agentsFile = ''
              Before starting any task, read and follow the instructions in
              ~/Develop/nix-config/dotfiles/agents/AGENTS.md.
            '';
          };
        };
    };
  };
}
