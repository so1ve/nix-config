{
  ray.features."hardware/ryzen-boost" = {
    nixos =
      _:
      { pkgs, ... }:
      let
        ryzenBoostApply = pkgs.writeShellScript "ryzen-boost-apply" ''
          set -u
          ryzenadj="${pkgs.ryzenadj}/bin/ryzenadj"

          ac_online() {
            for ps in /sys/class/power_supply/*; do
              if [ -r "$ps/type" ] && [ "$(cat "$ps/type" 2>/dev/null)" = "Mains" ] \
                && [ -r "$ps/online" ] && [ "$(cat "$ps/online" 2>/dev/null)" = "1" ]; then
                return 0
              fi
            done
            return 1
          }

          apply_stock() {
            "$ryzenadj" --stapm-limit=29000 --fast-limit=35000 --slow-limit=29000 --tctl-temp=80 >/dev/null 2>&1 || true
          }

          if [ "''${1:-}" = "reset" ]; then
            apply_stock
            exit 0
          fi

          while true; do
            if ac_online; then
              "$ryzenadj" --stapm-limit=42000 --fast-limit=48000 --slow-limit=42000 --tctl-temp=85 >/dev/null 2>&1 || true
            else
              apply_stock
            fi
            sleep 10
          done
        '';

        ryzenBoostCli = pkgs.writeShellScriptBin "ryzen-boost" ''
          set -euo pipefail
          case "''${1:-status}" in
            on|start)
              systemctl start ryzen-boost.service
              echo "ryzen-boost: active (42W/48W @ 85C on AC, auto-refreshed every 10s)"
              ;;
            off|stop)
              systemctl stop ryzen-boost.service
              echo "ryzen-boost: inactive (restored stock 29W)"
              ;;
            status)
              state="$(systemctl is-active ryzen-boost.service 2>/dev/null || true)"
              echo "service: $state"
              for ps in /sys/class/power_supply/*; do
                if [ -r "$ps/type" ] && [ "$(cat "$ps/type" 2>/dev/null)" = "Mains" ]; then
                  echo "ac_online: $(cat "$ps/online" 2>/dev/null || echo unknown)"
                  break
                fi
              done
              for d in /sys/class/drm/card*/device; do
                [ -r "$d/gpu_busy_percent" ] || continue
                echo "gpu_busy: $(cat "$d/gpu_busy_percent")%"
                grep '\*' "$d/pp_dpm_sclk" 2>/dev/null | sed 's/^/gpu_clock: /' || true
                for h in "$d"/hwmon/hwmon*; do
                  [ -r "$h/power1_average" ] && awk '{printf "apu_power: %.1f W\n", $1/1e6}' "$h/power1_average"
                  [ -r "$h/temp1_input" ] && awk '{printf "apu_temp: %.1f C\n", $1/1e3}' "$h/temp1_input"
                done
                break
              done
              awk '/cpu MHz/{s+=$4; n++} END{if(n>0) printf "cpu_avg: %.0f MHz\n", s/n}' /proc/cpuinfo
              ;;
            *)
              echo "Usage: ryzen-boost [on|off|status]" >&2
              exit 2
              ;;
          esac
        '';
      in
      {
        environment.systemPackages = with pkgs; [
          ryzenadj
          ryzenBoostCli
        ];

        security.polkit.extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (
              action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "ryzen-boost.service" &&
              subject.isInGroup("wheel")
            ) {
              return polkit.Result.YES;
            }
          });
        '';

        systemd.services.ryzen-boost = {
          description = "Ryzen APU sustained power boost on AC (keepalive against EC reset)";
          path = [ pkgs.coreutils ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${ryzenBoostApply}";
            ExecStopPost = "${ryzenBoostApply} reset";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };

        programs.gamemode.settings.custom = {
          start = "${pkgs.systemd}/bin/systemctl --no-block start ryzen-boost.service";
          end = "${pkgs.systemd}/bin/systemctl --no-block stop ryzen-boost.service";
        };
      };
  };
}
