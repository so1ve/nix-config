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
  ryzenadj \
    --stapm-limit=29000 --fast-limit=35000 --slow-limit=29000 \
    --apu-slow-limit=29000 --skin-temp-limit=29000 --apu-skin-temp=45 \
    --tctl-temp=80 >/dev/null 2>&1 || true
}

if [ "${1:-}" = "reset" ]; then
  if ac_online; then
    apply_stock
  fi
  exit 0
fi

while ac_online; do
  ryzenadj \
    --stapm-limit=42000 --fast-limit=48000 --slow-limit=42000 \
    --apu-slow-limit=42000 --skin-temp-limit=42000 --apu-skin-temp=55 \
    --tctl-temp=85 >/dev/null 2>&1 || true
  sleep 2
done
