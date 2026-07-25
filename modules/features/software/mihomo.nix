{
  ray.features."software/mihomo" = {
    nixos =
      {
        pkgs,
        username,
        ...
      }:
      {
        services.mihomo = {
          enable = true;
          configFile = "/home/${username}/.config/mihomo/config.yaml";
          webui = pkgs.zashboard;
          tunMode = true;
        };

        # Avoid making the first proxy startup depend on downloading its GeoIP
        # database through a proxy that is not running yet.
        systemd.services.mihomo.serviceConfig.BindReadOnlyPaths = [
          "${pkgs.dbip-country-lite.mmdb}:/var/lib/private/mihomo/Country.mmdb"
        ];

        # Strict reverse-path filtering can reject traffic routed through the
        # TUN interface.
        networking.firewall.checkReversePath = "loose";
      };

    home =
      {
        config,
        lib,
        mkFirefoxPwaInstall,
        pkgs,
        ...
      }:
      let
        manifestUrl = "http://127.0.0.1:9090/ui/manifest.webmanifest";

        showZashboardSecret = pkgs.writeShellApplication {
          name = "zashboard-secret";
          runtimeInputs = [ pkgs.yq-go ];
          text = ''
            exec yq --unwrapScalar '.secret // ""' \
              ${lib.escapeShellArg "${config.xdg.configHome}/mihomo/config.yaml"}
          '';
        };
      in
      lib.mkMerge [
        (mkFirefoxPwaInstall {
          inherit
            config
            lib
            manifestUrl
            pkgs
            ;
          name = "zashboard";
          description = "Install Zashboard as a Firefox PWA";
          waitForManifest = true;
          timeoutStartSec = 45;
        })

        {
          home.packages = [ showZashboardSecret ];
        }
      ];
  };
}
