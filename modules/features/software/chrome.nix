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
        inputs,
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
          ];
        };
        urlRouter = inputs.chrome-url-router.lib.mkGoogleChromeRouter {
          inherit pkgs;
          browser = chrome;
        };
        focusOrLaunch = mkFocusOrLaunch pkgs;
        chromeLauncher = pkgs.writeShellApplication {
          name = "google-chrome-stable";
          text = ''
            app_id=""
            profile="Default"

            for argument in "$@"; do
              case "$argument" in
                --app-id=*) app_id="''${argument#--app-id=}" ;;
                --profile-directory=*) profile="''${argument#--profile-directory=}" ;;
              esac
            done

            if [[ -n "$app_id" ]]; then
              profile="''${profile// /_}"
              exec ${lib.getExe focusOrLaunch} \
                "chrome-$app_id-$profile" \
                ${lib.getExe chrome} "$@"
            fi

            exec ${lib.getExe urlRouter.launcher} "$@"
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
          configFile."google-chrome/NativeMessagingHosts/${urlRouter.nativeHostName}.json".source =
            urlRouter.nativeMessagingHostManifest;

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
