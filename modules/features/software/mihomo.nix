{
  ray.features."software/mihomo" = {
    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        services.mihomo = {
          enable = true;
          configFile = config.age.secrets.mihomo-config.path;
          webui = pkgs.zashboard;
          tunMode = true;
        };

        # Avoid making the first proxy startup depend on downloading its GeoIP
        # database through a proxy that is not running yet.
        systemd.services.mihomo = {
          # Mihomo can initialize its TUN and listeners before connectivity is
          # established.  Waiting for DHCP here only delays the whole desktop.
          requires = lib.mkForce [ ];
          wants = [ "network.target" ];
          after = lib.mkForce [ "network.target" ];
          restartTriggers = [ config.age.secrets.mihomo-config.file ];
          serviceConfig.BindReadOnlyPaths = [
            "${pkgs.dbip-country-lite.mmdb}:/var/lib/private/mihomo/Country.mmdb"
          ];
        };

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
        mihomoConfig = "/run/agenix/mihomo-config";

        showZashboardSecret = pkgs.writeShellApplication {
          name = "zashboard-secret";
          runtimeInputs = [ pkgs.yq-go ];
          text = ''
            exec yq --unwrapScalar '.secret // ""' \
              ${lib.escapeShellArg mihomoConfig}
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

          xdg.configFile."mihomo/config.yaml" = {
            source = config.lib.file.mkOutOfStoreSymlink mihomoConfig;
            force = true;
          };
        }
      ];
  };
}
