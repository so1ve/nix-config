{
  ray.features = {
    "software/codex".home =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.codex ];
        home.file.".codex/AGENTS.md".text = ''
            <global_operating_constraints>
            # Global operating constraints

            These constraints are mandatory. A normal request to inspect, edit, fix,
            implement, clean up, or finish work does not override them.

            <file_editing>
            ## File editing and paths

            - By default, NEVER use an absolute path as the target of an edit, write, or
              patch operation. Use a path relative to the current workspace or repository
              root instead.
            - Paths under `/tmp` and the exact path `/dev/null` are always exceptions.
            - An absolute path outside the current workspace is also allowed, but only when
              the user explicitly asks to edit that external file or location and there is
              no better, equally quick relative-path or built-in-tool method. Limit the edit
              to the exact external target the user authorized.
            - This restriction applies to mutations, including paths passed to editing tools.
              It does not prohibit reading or citing an absolute path.
            - If an editing method appears to require an absolute path inside the workspace,
              choose a relative-path or workspace-relative method instead. Do not fall back
              to the absolute path, because doing so breaks permission-system auto-review
              and forces the user to decide manually.
            </file_editing>

            <external_actions>
            ## Git history and external publication

            - NEVER create or amend a commit, push a branch, open or update a pull request,
              create an issue, or send a pull-request/issue comment or review unless the
              user explicitly requests that specific action.
            - Editing or preparing a change does not authorize committing, publishing, or
              communicating with third parties.
            - Read-only Git and forge inspection is allowed when it is relevant.
            </external_actions>

            <nixos_rebuilds>
            ## NixOS rebuilds

            - NEVER run or attempt a NixOS rebuild, switch, test, boot, activation, or an
              equivalent operation. This includes `nixos-rebuild`, `nh os`, and direct
              system activation commands.
            - When applying a change requires a NixOS rebuild, give the user the command
              and ask them to run it themselves.
            </nixos_rebuilds>

            <local_builds>
            ## Local builds

            - NEVER build or compile a program locally unless the user explicitly approves
              that specific build in the current conversation context.
            - An implementation request is not build approval. By default, stop before the
              build, give the user the exact command, and ask them to run it and share the
              result.
            - This includes build-capable checks and tests. In particular, do not run
              `nix build`, a `nix flake check` that realizes derivations, `cargo build`,
              `cargo check`, `cargo test`, `rustc`, or equivalent build commands without
              that explicit approval.
            - Before running an unfamiliar validation command, determine whether it may
              compile software or realize build derivations. If it may, treat it as a build.
            </local_builds>

            <tool_selection>
            ## Tool selection

            - Whenever a specialized built-in tool can perform an operation, ALWAYS use it
              instead of a shell command. Prefer built-in read, search, edit, and patch
              capabilities over shell equivalents.
            - Use the shell only when no available built-in tool can perform the operation
              or when the shell is materially required by the task.
            </tool_selection>
            </global_operating_constraints>
        '';
      };

    "software/codex/deepseek" = {
      requires = [
        "software/codex"
        "software/shell"
        "security/agenix"
      ];

      home =
        {
          config,
          inputs,
          pkgs,
          ...
        }:
        let
          toml = pkgs.formats.toml { };
        in
        {
          age.secrets.deepseek-api-key = {
            file = "${inputs.self}/secrets/deepseek-api-key.age";
            path = "${config.xdg.configHome}/deepseek/api-key";
          };

          programs.fish.shellAbbrs.dodex = "codex -p deepseek";

          home.file = {
            ".codex/deepseek.config.toml".source = toml.generate "codex-deepseek-config.toml" {
              model = "deepseek-v4-pro";
              model_provider = "deepseek";
              model_reasoning_effort = "high";
              model_catalog_json = "${config.home.homeDirectory}/.codex/models.json";

              model_providers.deepseek = {
                name = "DeepSeek";
                base_url = "https://api.deepseek.com/";
                wire_api = "responses";
                supports_websockets = false;
                auth = {
                  command = "${pkgs.coreutils}/bin/cat";
                  args = [ config.age.secrets.deepseek-api-key.path ];
                };
              };
            };

            # Snapshot from DeepSeek's official Codex setup script (v1.1.0,
            # fetched 2026-08-13). It describes V4 Flash and V4 Pro metadata;
            # the profile above selects V4 Pro (DeepSeek-V4-Pro-0813).
            ".codex/models.json".source = ../../../dotfiles/codex/models.json;
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
          extraPackages = with pkgs; [
            git
            nodejs
            pnpm
          ];
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
              "npm:@ff-labs/pi-fff"
              "npm:@gotgenes/pi-permission-system"
              "npm:@gotgenes/pi-subagents"
              "npm:@gotgenes/pi-subagents-worktrees"
              "npm:@juicesharp/rpiv-ask-user-question"
              "npm:@mzwing/pi-permission-auto-review"
              "npm:@narumitw/pi-btw"
              "npm:@narumitw/pi-plan-mode"
              "npm:@narumitw/pi-usage"
              "npm:@upstash/context7-pi"
              "npm:pi-codex-goal"
              "npm:pi-effort"
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
