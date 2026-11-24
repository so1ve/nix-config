emit_check() {
  jq -n --arg status "$1" --arg summary "$2" \
    '{checks: [{key: "tailscale", label: "Tailscale", group: "network", status: $status, summary: $summary}]}'
}

if ! systemctl is-active --quiet tailscaled.service; then
  emit_check fail stopped
  exit 0
fi

if ! out=$(tailscale status --peers=false 2>&1); then
  msg=$(printf '%s\n' "$out" | awk 'NR==1{print; exit}')
  emit_check fail "${msg:-error}"
  exit 0
fi

ip=$(printf '%s\n' "$out" | awk 'NR==1{print $1; exit}')
if [ -n "$ip" ]; then
  jq -n --arg ip "$ip" '{
    checks: [{key: "tailscale", label: "Tailscale", group: "network", status: "ok", summary: "active"}],
    info: [{key: "tailscale_ip", label: "Tailscale IP", group: "network", value: $ip}]
  }'
else
  emit_check fail disconnected
fi
