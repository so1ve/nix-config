export DISABLE_LSFGVK="${DISABLE_LSFGVK:-1}"

LOG="/tmp/endfield-wrap.log"
: > "$LOG"

log() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >> "$LOG"
}

find_launcher_pids() {
  pgrep -f 'Hypergryph Launcher.*(Games\.exe|QtWebEngineProcess\.exe)' 2>/dev/null || true
}

find_game_pids() {
  pgrep -f 'Arknights Endfield.*Endfield\.exe' 2>/dev/null || true
}

watcher() {
  log "Watcher started, waiting for Endfield.exe..."
  local waited=0
  while [ "$waited" -lt 600 ]; do
    if [ -n "$(find_game_pids)" ]; then
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done

  if [ -z "$(find_game_pids)" ]; then
    log "Endfield.exe never started; exiting watcher."
    return 0
  fi

  log "Endfield.exe detected! Waiting 8s for handshake before freezing launcher..."
  sleep 8

  local -a lpids=()
  mapfile -t lpids < <(find_launcher_pids)
  if [ "${#lpids[@]}" -gt 0 ]; then
    log "Freezing (SIGSTOP) launcher PIDs: ${lpids[*]}"
    kill -STOP "${lpids[@]}" 2>/dev/null || true
  fi

  while [ -n "$(find_game_pids)" ]; do
    sleep 3
  done

  log "Endfield.exe exited; closing launcher cleanly..."
  lpids=()
  mapfile -t lpids < <(find_launcher_pids)
  if [ "${#lpids[@]}" -gt 0 ]; then
    kill -CONT "${lpids[@]}" 2>/dev/null || true
    kill -TERM "${lpids[@]}" 2>/dev/null || true
    sleep 2
    kill -KILL "${lpids[@]}" 2>/dev/null || true
  fi
}

watcher &
WATCHER_PID=$!
trap 'kill "$WATCHER_PID" 2>/dev/null || true' EXIT

gamescope \
  -W "${ENDFIELD_OUT_W:-3840}" -H "${ENDFIELD_OUT_H:-2160}" \
  -w "${ENDFIELD_W:-2560}" -h "${ENDFIELD_H:-1440}" \
  -r "${ENDFIELD_FPS:-60}" \
  -F fsr --fsr-sharpness "${ENDFIELD_FSR_SHARPNESS:-8}" \
  -f -- \
  gamemoderun mangohud "$@"
