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
          commandLineArgs = "--enable-features=${lib.concatStringsSep "," chromeFeatures}";
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
            open_in_tabs=true
            profile="Default"

            (( $# > 0 )) || open_in_tabs=false

            for argument in "$@"; do
              case "$argument" in
                --app-id=*) app_id="''${argument#--app-id=}" ;;
                --profile-directory=*) profile="''${argument#--profile-directory=}" ;;
                http://* | https://* | file://*) ;;
                *) open_in_tabs=false ;;
              esac
            done

            if [[ -n "$app_id" ]]; then
              profile="''${profile// /_}"
              exec ${lib.getExe focusOrLaunch} \
                "chrome-$app_id-$profile" \
                ${lib.getExe chrome} "$@"
            fi

            if $open_in_tabs; then
              window_id="$(
                niri msg -j windows 2>/dev/null \
                  | jq -r '
                      map(select(.app_id | test("^google-chrome(-stable)?$"; "i")))
                      | max_by(.focus_timestamp.secs, .focus_timestamp.nanos)
                      | .id // empty
                    '
              )" || true

              if [[ -n "$window_id" ]] \
                && niri msg action focus-window --id "$window_id" >/dev/null 2>&1; then
                clipboard_file="$(mktemp)"
                clipboard_type="$(wl-paste --list-types 2>/dev/null | sed -n '1p')" || true

                restore_clipboard() {
                  if [[ -n "$clipboard_type" ]]; then
                    wl-copy --type "$clipboard_type" < "$clipboard_file" || true
                  else
                    wl-copy --clear || true
                  fi
                  rm -f -- "$clipboard_file"
                }
                trap restore_clipboard EXIT

                if [[ -z "$clipboard_type" ]] \
                  || wl-paste --type "$clipboard_type" > "$clipboard_file" 2>/dev/null; then
                  for url in "$@"; do
                    printf %s "$url" \
                      | wl-copy --sensitive --type 'text/plain;charset=utf-8'
                    wtype -M ctrl -k t -m ctrl -s 100 \
                      -M ctrl -k v -m ctrl -s 20 -k Return -s 50
                  done
                  exit
                fi

                trap - EXIT
                rm -f -- "$clipboard_file"
              fi
            fi

            exec ${lib.getExe chrome} "$@"
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
