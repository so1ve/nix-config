case "${1:-status}" in
  on|start)
    systemctl start ryzen-boost.service
    echo "ryzen-boost: active (42W/48W @ 85C on AC, auto-refreshed every 2s)"
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
        if [ -r "$h/power1_average" ]; then
          awk '{printf "apu_power: %.1f W\n", $1/1e6}' "$h/power1_average"
        fi
        if [ -r "$h/temp1_input" ]; then
          awk '{printf "apu_temp: %.1f C\n", $1/1e3}' "$h/temp1_input"
        fi
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
