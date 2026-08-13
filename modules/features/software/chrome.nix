{
  ray.features."software/chrome" = {
    nixos =
      { config, lib, ... }:
      {
        options.ray.chromeWebApps = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              freeformType = lib.types.attrsOf lib.types.anything;
              options = {
                url = lib.mkOption {
                  type = lib.types.str;
                };
                custom_name = lib.mkOption {
                  type = lib.types.str;
                };
                create_desktop_shortcut = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                };
                default_launch_container = lib.mkOption {
                  type = lib.types.enum [
                    "tab"
                    "window"
                  ];
                  default = "window";
                };
              };
            }
          );
          default = [ ];
          description = "Web apps force-installed by Google Chrome policy.";
        };

        config.environment.etc."opt/chrome/policies/managed/ray.json".text = builtins.toJSON {
          CommandLineFlagSecurityWarningsEnabled = false;
          DefaultBrowserSettingEnabled = false;
          WebAppInstallForceList = config.ray.chromeWebApps;
        };
      };

    home =
      {
        lib,
        mkFocusOrLaunch,
        pkgs,
        ...
      }:
      let
        chromeFeatures = [
          "ForceEnableWebGpuInterop"
          "VerticalTabs"
          "WaylandWindowDecorations"
        ];
        chrome = pkgs.google-chrome.override {
          commandLineArgs = lib.concatStringsSep " " [
            "--enable-features=${lib.concatStringsSep "," chromeFeatures}"
            "--enable-blink-features=MiddleClickAutoscroll"
            # Keep PWA link handling off: target=_blank/out-of-scope links from
            # PWA windows then open as browser tabs, reusing the existing
            # regular browser window instead of spawning a new window.
            "--disable-features=PwaNavigationCapturing"
          ];
        };
        focusOrLaunch = mkFocusOrLaunch pkgs;
        chromeLauncher = pkgs.writeShellApplication {
          name = "google-chrome-stable";
          runtimeInputs = [
            pkgs.jq
            pkgs.niri
            pkgs.wl-clipboard
            pkgs.wtype
          ];
          text = ''
            app_id=""
            profile="Default"

            for argument in "$@"; do
              case "$argument" in
                --app-id=*) app_id="''${argument#--app-id=}" ;;
                --profile-directory=*) profile="''${argument#--profile-directory=}" ;;
              esac
            done

            chrome=("${lib.getExe chrome}" "$@")

            if [[ -n "$app_id" ]]; then
              profile="''${profile// /_}"
              exec ${lib.getExe focusOrLaunch} \
                "chrome-$app_id-$profile" \
                "''${chrome[@]}"
            fi

            (( $# > 0 )) || exec "''${chrome[@]}"
            for url in "$@"; do
              case "$url" in
                http://* | https://* | file://*) ;;
                *) exec "''${chrome[@]}" ;;
              esac
            done

            window_id="$(
              niri msg -j windows 2>/dev/null \
                | jq -r '
                    map(select(.app_id | test("^google-chrome(-stable)?$"; "i")))
                    | max_by([.focus_timestamp.secs, .focus_timestamp.nanos])
                    | .id // empty
                  '
            )" || true
            [[ -n "$window_id" ]] || exec "''${chrome[@]}"
            niri msg action focus-window --id "$window_id" >/dev/null 2>&1 \
              || exec "''${chrome[@]}"

            # Let niri finish focusing (possibly switching workspaces) before
            # injecting keystrokes.
            sleep 0.15

            clipboard_file="$(mktemp)"
            clipboard_type="$(wl-paste --list-types 2>/dev/null | sed -n '1p')" || true
            if [[ -n "$clipboard_type" ]] \
              && ! wl-paste --type "$clipboard_type" > "$clipboard_file" 2>/dev/null; then
              rm -f -- "$clipboard_file"
              exec "''${chrome[@]}"
            fi

            restore_clipboard() {
              if [[ -n "$clipboard_type" ]]; then
                wl-copy --type "$clipboard_type" < "$clipboard_file" || true
              else
                wl-copy --clear || true
              fi
              rm -f -- "$clipboard_file"
            }
            trap restore_clipboard EXIT

            for url in "$@"; do
              printf %s "$url" \
                | wl-copy --sensitive --type 'text/plain;charset=utf-8'
              wtype -s 200 -M ctrl -k t -m ctrl \
                -s 100 -M ctrl -k v -m ctrl -s 20 -k Return -s 50
            done
          '';
        };
      in
      {
        home = {
          packages = [
            (lib.hiPrio chromeLauncher)
            chrome
          ];
          sessionVariables.BROWSER = lib.getExe chromeLauncher;
        };

        xdg = {
          desktopEntries.open-in-google-chrome = {
            name = "Google Chrome URL Handler";
            exec = "${lib.getExe chromeLauncher} %U";
            icon = "google-chrome";
            mimeType = [
              "application/xhtml+xml"
              "text/html"
              "x-scheme-handler/http"
              "x-scheme-handler/https"
            ];
            noDisplay = true;
            terminal = false;
          };

          mimeApps = {
            enable = true;
            defaultApplications = lib.genAttrs [
              "application/xhtml+xml"
              "text/html"
              "x-scheme-handler/http"
              "x-scheme-handler/https"
            ] (_: "open-in-google-chrome.desktop");
          };
        };
      };
  };
}
