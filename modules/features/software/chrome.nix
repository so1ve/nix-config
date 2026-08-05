{
  ray.features."software/chrome" = {
    nixos =
      { config, lib, ... }:
      {
        options.ray.chromeWebApps = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
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
          });
          default = [ ];
          description = "Web apps force-installed by Google Chrome policy.";
        };

        config.environment.etc."opt/chrome/policies/managed/ray.json".text = builtins.toJSON {
          WebAppInstallForceList = config.ray.chromeWebApps;
        };
      };

    home =
      { lib, pkgs, ... }:
      {
        home = {
          packages = [ pkgs.google-chrome ];
          sessionVariables.BROWSER = lib.getExe pkgs.google-chrome;
        };

        xdg.mimeApps = {
          enable = true;
          defaultApplications = lib.genAttrs [
            "application/xhtml+xml"
            "text/html"
            "x-scheme-handler/http"
            "x-scheme-handler/https"
          ] (_: "google-chrome.desktop");
        };
      };
  };
}
