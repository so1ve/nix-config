{ ... }:
{
  ray.features = {
    "software/agent-skills".home =
      { inputs, ... }:
      {
        imports = [ inputs.agent-skills.homeManagerModules.default ];

        programs.agent-skills = {
          enable = true;
          sources = {
            cloudflare = {
              input = "cloudflare-skills";
              subdir = "skills";
            };
            local.path = ../../../dotfiles/agents/skills;
          };
          skills.enableAll = true;
          targets.agents = {
            enable = true;
            dest = ".agents/skills";
            structure = "link";
          };
        };
      };

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
          packages = [ inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex ];
          file.".codex/AGENTS.md".source = mkDotfilesSymlink {
            inherit config;
            name = "agents/AGENTS.md";
          };
        };
      };

    "software/codex-desktop" = {
      nixos =
        { config, username, ... }:
        {
          services.gnome.at-spi2-core.enable = true;

          # Computer Use uses uinput for the pointer and ydotool for keyboard input.
          hardware.uinput.enable = true;
          programs.ydotool.enable = true;
          users.users.${username}.extraGroups = [
            "uinput"
            config.programs.ydotool.group
          ];
        };

      home =
        {
          inputs,
          lib,
          pkgs,
          ...
        }:
        let
          linuxFeatures = [
            "api-key-model-visibility"
            "appshots"
            "computer-use-linux"
            "mcp-helper-reaper"
            "node-repl-reaper"
            "ui-tweaks"
          ];

          linuxFeaturesConfig = pkgs.writeText "codex-linux-features.json" (
            builtins.toJSON {
              enabled = upstreamDesktop.passthru.effectiveLinuxFeatureIds;
              settings."ui-tweaks".tweaks = {
                home.suggestedPrompts.enabled = false;
                # FIXME: This optional tweak is tightly coupled to the minified webview
                # bundle and currently drifts on desktop 26.901.31953.
                modelPicker.showModelsByDefault.enabled = false;
                reasoning.keepEffortLabelsEnglish.enabled = true;
                sidebar.projectName.enabled = false;
              };
            }
          );

          upstreamDesktop =
            inputs.codex-desktop.packages.${pkgs.stdenv.hostPlatform.system}.codex-desktop.override
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
          imports = [ inputs.codex-desktop.homeManagerModules.default ];

          programs.codexDesktopLinux = {
            enable = true;
            package = desktop;
          };

          home.packages = [
            pkgs.bubblewrap
            # AppShots needs a Wayland-capable screenshot backend.
            pkgs.grim
          ];
        };
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

    "software/omp" = {
      requires.allOf = [ "security/agenix" ];

      home =
        {
          config,
          inputs,
          mkDotfilesSymlink,
          pkgs,
          ...
        }:
        {
          age.secrets.omp-models = {
            file = "${inputs.self}/secrets/omp-models.age";
            path = "${config.home.homeDirectory}/.omp/agent/models.yml";
          };

          home = {
            packages = [ inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp ];
            file = {
              ".omp/agent/AGENTS.md".source = mkDotfilesSymlink {
                inherit config;
                name = "agents/AGENTS.md";
              };
            };
          };
        };
    };

    "software/dsh" = {
      requires.allOf = [ "security/agenix" ];

      home =
        {
          config,
          inputs,
          pkgs,
          ...
        }:
        let
          rea = (import inputs.so1ve { inherit pkgs; }).rea;
          tailscaleHosts = [
            "100.64.0.1"
            "[fd7a:115c:a1e0::1]"
            "workstation"
            "workstation.example.ts.net"
          ];
        in
        {
          imports = [ inputs.so1ve.homeModules.deepseek-harness ];

          age.secrets.dsh-env = {
            file = "${inputs.self}/secrets/dsh-env.age";
            path = "${config.home.homeDirectory}/.dsh/.env";
          };

          home = {
            packages = [ rea ];
            file.".dsh/skills/reverse-engineer-anything".source =
              "${rea}/share/rea/node_modules/rea-agents/skills/reverse-engineer-anything";
          };

          programs.deepseek-harness = {
            enable = true;
            profiles.web = {
              plugins = [
                "npm:@deepseek-ai/dsh-base"
                "npm:@deepseek-ai/dsh-web-app"
                "github:YuJunZhiXue/dsh-purge"
              ];
            };
            # The Web UI rewrites its profile patch when saving settings.
            # Keep declarative overrides in the separate home-level layer.
            cordisPatch = [
              {
                id = "connection";
                config.trustedHosts.__jsExpr = "${builtins.toJSON tailscaleHosts}.concat(ctx.webRuntime.trustedHosts)";
              }
              {
                insert = [
                  {
                    id = "rea-mcp";
                    name = "@deepseek-ai/dsh-mcp-client";
                    config = {
                      serverName = "rea";
                      transport = "stdio";
                      command = "${rea}/bin/rea";
                      args = [ "mcp" ];
                      toolCallTimeoutMs = 450000;
                      reconnect.enabled = false;
                    };
                  }
                ];
              }
            ];
            agentsFile = ''
              Before starting any task, read and follow the instructions in
              ~/Develop/nix-config/dotfiles/agents/AGENTS.md.
            '';
          };
        };
    };
  };
}
