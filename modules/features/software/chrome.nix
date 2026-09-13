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
                appId = lib.mkOption {
                  type = lib.types.strMatching "[a-p]{32}";
                  description = "Installed app ID from chrome://web-app-internals.";
                };
                url = lib.mkOption {
                  type = lib.types.str;
                };
                custom_name = lib.mkOption {
                  type = lib.types.str;
                };
                create_desktop_shortcut = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
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
          WebAppInstallForceList = map (app: builtins.removeAttrs app [ "appId" ]) config.ray.chromeWebApps;
        };
      };

    home =
      {
        config,
        inputs,
        lib,
        mkFocusOrLaunch,
        osConfig,
        pkgs,
        ...
      }:
      let
        chromeFeatures = [
          "ForceEnableWebGpuInterop"
          "VerticalTabs"
          "WaylandWindowDecorations"
        ];
        chrome =
          (pkgs.google-chrome.override {
            commandLineArgs = lib.concatStringsSep " " [
              "--enable-features=${lib.concatStringsSep "," chromeFeatures}"
              "--enable-blink-features=MiddleClickAutoscroll"
            ];
          }).overrideAttrs
            (old: {
              # Cover direct browser launches as well as the URL/PWA launcher.
              # Chrome names shortcuts by profile name, ignoring user-data-dir.
              postFixup = (old.postFixup or "") + ''
                wrapProgram "$out/bin/google-chrome-stable" \
                  --prefix PATH : ${lib.makeBinPath [ pkgs.coreutils ]} \
                  --run ${lib.escapeShellArg "source ${./chrome/isolate-profile.sh}"}
              '';
            });
        webApps = pkgs.writeText "chrome-web-apps.json" (
          builtins.toJSON (map (app: { inherit (app) appId custom_name; }) osConfig.ray.chromeWebApps)
        );
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
        # Migrate shortcuts previously overwritten by temporary Playwright profiles.
        home.activation.repairChromeWebAppShortcuts = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          run ${lib.getExe pkgs.python3} ${./chrome/repair-shortcuts.py} \
            ${webApps} \
            ${lib.escapeShellArg "${config.xdg.dataHome}/applications"} \
            ${lib.escapeShellArg "${config.xdg.stateHome}/chrome-shortcut-backups"}
        '';

        home.packages = [
          (lib.hiPrio chromeLauncher)
          chrome
        ];

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
        };
      };
  };

  ray.features."defaults/browser/chrome" = {
    requires.allOf = [ "software/chrome" ];
    home =
      { lib, ... }:
      {
        home.sessionVariables.BROWSER = "google-chrome-stable";

        xdg.mimeApps = {
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
}
