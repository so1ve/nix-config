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
        pkgs,
        ...
      }:
      let
        manifestUrl = "http://127.0.0.1:9090/ui/manifest.webmanifest";
        firefoxPwaConfig = "${config.xdg.dataHome}/firefoxpwa/config.json";

        installZashboardPwa = pkgs.writeShellScript "install-zashboard-pwa" ''
          set -eu

          manifest_url=${lib.escapeShellArg manifestUrl}
          pwa_config=${lib.escapeShellArg firefoxPwaConfig}

          for attempt in $(${pkgs.coreutils}/bin/seq 1 30); do
            if ${pkgs.curl}/bin/curl --fail --silent --show-error \
              --output /dev/null "$manifest_url"; then
              break
            fi

            if [ "$attempt" -eq 30 ]; then
              exit 1
            fi

            ${pkgs.coreutils}/bin/sleep 1
          done

          if [ -f "$pwa_config" ] \
            && ${pkgs.gnugrep}/bin/grep --fixed-strings --quiet \
              "$manifest_url" "$pwa_config"; then
            exit 0
          fi

          exec ${lib.getExe pkgs.firefoxpwa} site install "$manifest_url"
        '';

        showZashboardSecret = pkgs.writeShellApplication {
          name = "zashboard-secret";
          runtimeInputs = [ pkgs.yq-go ];
          text = ''
            exec yq --unwrapScalar '.secret // ""' \
              ${lib.escapeShellArg "${config.xdg.configHome}/mihomo/config.yaml"}
          '';
        };
      in
      {
        home.packages = [
          pkgs.firefoxpwa
          showZashboardSecret
        ];

        programs.firefox.nativeMessagingHosts = [ pkgs.firefoxpwa ];

        systemd.user.services.zashboard-pwa-install = {
          Unit = {
            Description = "Install Zashboard as a Firefox PWA";
            After = [ "graphical-session.target" ];
          };

          Service = {
            Type = "oneshot";
            ExecStart = "${installZashboardPwa}";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = 10;
            TimeoutStartSec = 45;
          };

          Install.WantedBy = [ "graphical-session.target" ];
        };
      };
  };
}
