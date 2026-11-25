{ images, lib, ... }:

{
  ray.features."services/yanqi" = {
    requires.allOf = [
      "security/agenix"
      "virtualisation/podman"
    ];

    options = {
      account = lib.mkOption {
        type = lib.types.str;
        description = "QQ account to log in automatically using the saved NapCat session.";
      };

      napcat = {
        webPort = lib.mkOption {
          type = lib.types.port;
          description = "Host port for NapCat's web interface.";
        };
      };
    };

    nixos =
      { settings, ... }:
      {
        config,
        featureEnabled,
        pkgs,
        ...
      }:
      let
        inherit (config.virtualisation.quadlet) containers networks volumes;
        yanqiCheck = lib.getExe (
          pkgs.writeShellApplication {
            name = "uptarn-check-yanqi";
            runtimeInputs = [
              pkgs.bind.host
              pkgs.curl
              pkgs.gawk
              pkgs.iproute2
              pkgs.systemd
            ];
            text = ''
              if ! systemctl is-active --quiet ${lib.escapeShellArg "${containers.yanqi.serviceName}.service"}; then
                echo "yanqi service inactive"
                exit 1
              fi

              if ! systemctl is-active --quiet ${lib.escapeShellArg "${containers.yanqi-napcat.serviceName}.service"}; then
                echo "napcat service inactive"
                exit 1
              fi

              dns=$(ip -4 -o addr show dev br-yanqi 2>/dev/null | awk '{sub(/\/.*/, "", $4); print $4; exit}' || true)
              if [ -z "$dns" ]; then
                echo "br-yanqi down"
                exit 1
              fi

              yanqi_ip=$(host -W 1 -t A yanqi "$dns" 2>/dev/null | awk '/ has address /{print $4; exit}' || true)
              if [ -z "$yanqi_ip" ]; then
                echo "yanqi DNS unresolved"
                exit 1
              fi

              napcat_ip=$(host -W 1 -t A napcat "$dns" 2>/dev/null | awk '/ has address /{print $4; exit}' || true)
              if [ -z "$napcat_ip" ]; then
                echo "napcat DNS unresolved"
                exit 1
              fi

              web_code=$(curl -sS --max-time 2 -o /dev/null -w '%{http_code}' "http://$yanqi_ip:3000/" 2>/dev/null || true)
              if [ "$web_code" != "200" ]; then
                echo "web UI unhealthy (HTTP ''${web_code:-000})"
                exit 1
              fi

              ws_code=$(curl -sS --max-time 2 -o /dev/null -w '%{http_code}' "http://$napcat_ip:3001/" 2>/dev/null || true)
              if [ -z "$ws_code" ] || [ "$ws_code" = "000" ]; then
                echo "napcat offline (OneBot WS :3001 unreachable)"
                exit 1
              fi

              echo "online (web + napcat ws)"
            '';
          }
        );
      in
      {
        networking.firewall.interfaces.br-yanqi = {
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };

        virtualisation.quadlet = {
          volumes = {
            yanqi = { };
            yanqi-napcat-qq = { };
            yanqi-napcat-config = { };
          };

          networks.yanqi.networkConfig = {
            InterfaceName = "br-yanqi";
          };

          containers = {
            yanqi-napcat.containerConfig = {
              Image = images.napcat;
              Network = [ networks.yanqi.ref ];
              NetworkAlias = [ "napcat" ];
              PublishPort = [ "${toString settings.napcat.webPort}:6099" ];
              Volume = [
                "${volumes.yanqi-napcat-qq.ref}:/app/.config/QQ"
                "${volumes.yanqi-napcat-config.ref}:/app/napcat/config"
              ];
              Environment = {
                NAPCAT_QUICK_ACCOUNT = settings.account;
                MODE = "ws";
                NAPCAT_UID = "1000";
                NAPCAT_GID = "1000";
                TZ = config.time.timeZone;
              };
              EnvironmentFile = [ config.age.secrets.yanqi-napcat-env.path ];
            };

            yanqi = {
              unitConfig = {
                Wants = [ containers.yanqi-napcat.ref ];
                After = [ containers.yanqi-napcat.ref ];
              };
              containerConfig = {
                Image = images.yanqi;
                Network = [ networks.yanqi.ref ];
                NetworkAlias = [ "yanqi" ];
                PublishPort = [ "3210:3000" ];
                Volume = [ "${volumes.yanqi.ref}:/app/data" ];
                Environment.TZ = config.time.timeZone;
                NoNewPrivileges = true;
              };
            };
          };
        };

        systemd.services.${containers.yanqi-napcat.serviceName}.restartTriggers = [
          config.age.secrets.yanqi-napcat-env.file
        ];
      }
      // lib.optionalAttrs (featureEnabled "services/uptarn-agent") {
        ray.uptarn.execChecks = [
          {
            key = "yanqi";
            label = "Yanqi";
            group = "services";
            command = [ yanqiCheck ];
          }
        ];
      };
  };
}
