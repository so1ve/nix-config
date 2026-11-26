key=$1
label=$2
unit=$3
timer=$4
schedule=${5:-}

svc_active=""
svc_result=""
svc_start_ts=""
svc_exit_ts=""
svc_start_mono=0
svc_exit_mono=0
svc_exit_status=""

while IFS='=' read -r k v; do
  case "$k" in
    ActiveState) svc_active=$v ;;
    Result) svc_result=$v ;;
    ExecMainStartTimestamp) svc_start_ts=${v#@} ;;
    ExecMainExitTimestamp) svc_exit_ts=${v#@} ;;
    ExecMainStartTimestampMonotonic) svc_start_mono=${v:-0} ;;
    ExecMainExitTimestampMonotonic) svc_exit_mono=${v:-0} ;;
    ExecMainStatus) svc_exit_status=$v ;;
  esac
done < <(
  systemctl show --timestamp=unix "$unit"     -p ActiveState     -p Result     -p ExecMainStartTimestamp     -p ExecMainExitTimestamp     -p ExecMainStartTimestampMonotonic     -p ExecMainExitTimestampMonotonic     -p ExecMainStatus
)

timer_active=""
timer_last=""
timer_next=""
if [ -n "$timer" ]; then
  while IFS='=' read -r k v; do
    case "$k" in
      ActiveState) timer_active=$v ;;
      LastTriggerUSec) timer_last=${v#@} ;;
      NextElapseUSecRealtime) timer_next=${v#@} ;;
    esac
  done < <(
    systemctl show --timestamp=unix "$timer"       -p ActiveState       -p LastTriggerUSec       -p NextElapseUSecRealtime
  )
fi

last_run_at=""
if [[ "$svc_exit_ts" =~ ^[0-9]+$ && "$svc_exit_ts" -gt 0 ]]; then
  last_run_at=$svc_exit_ts
elif [[ "$svc_start_ts" =~ ^[0-9]+$ && "$svc_start_ts" -gt 0 ]]; then
  last_run_at=$svc_start_ts
elif [[ "$timer_last" =~ ^[0-9]+$ && "$timer_last" -gt 0 ]]; then
  last_run_at=$timer_last
fi

next_run_at=""
if [[ "$timer_next" =~ ^[0-9]+$ && "$timer_next" -gt 0 ]]; then
  next_run_at=$timer_next
fi

duration_ms=""
if [[ "$svc_start_mono" =~ ^[0-9]+$ && "$svc_exit_mono" =~ ^[0-9]+$ && "$svc_start_mono" -gt 0 && "$svc_exit_mono" -ge "$svc_start_mono" ]]; then
  duration_ms=$(( (svc_exit_mono - svc_start_mono) / 1000 ))
fi

detail=""
if [ "$svc_active" = "activating" ] || [ "$svc_active" = "active" ] || [ "$svc_active" = "reloading" ]; then
  status="running"
  summary="running"
elif [ "$svc_active" = "failed" ] || { [ -n "$svc_result" ] && [ "$svc_result" != "success" ]; }; then
  status="fail"
  summary="failed (${svc_result:-failed}, exit ${svc_exit_status:-?})"
  detail=$(journalctl -u "$unit" -n 20 --no-pager --output=cat 2>/dev/null | tail -c 1800 || true)
elif [ -n "$timer" ] && [ "$timer_active" != "active" ]; then
  status="fail"
  summary="timer ${timer_active:-inactive}"
elif [ -z "$last_run_at" ]; then
  status="pending"
  summary="waiting for first run"
else
  status="ok"
  summary="succeeded"
fi

jq -nc   --arg key "$key"   --arg label "$label"   --arg schedule "$schedule"   --arg status "$status"   --arg last_run_at "$last_run_at"   --arg next_run_at "$next_run_at"   --arg duration_ms "$duration_ms"   --arg summary "$summary"   --arg detail "$detail"   '{
    jobs: [
      ({ key: $key, label: $label, status: $status, summary: $summary }
        + (if $schedule != "" then { schedule: $schedule } else {} end)
        + (if $last_run_at != "" then { last_run_at: ($last_run_at | tonumber) } else {} end)
        + (if $next_run_at != "" then { next_run_at: ($next_run_at | tonumber) } else {} end)
        + (if $duration_ms != "" then { duration_ms: ($duration_ms | tonumber) } else {} end)
        + (if $detail != "" then { detail: $detail } else {} end))
    ]
  }'
