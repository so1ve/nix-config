cpu=$(awk -F: '/^model name/{gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || true)
ipv4=$(ip -4 -o addr show scope global 2>/dev/null \
  | awk '$2 !~ /^(lo|tailscale|docker|podman|br-|veth|cni|virbr|wg|tun|tap)/ {sub(/\/.*/, "", $4); print $4; exit}' || true)
ipv6=$(ip -6 -o addr show scope global -deprecated -temporary 2>/dev/null \
  | awk '$2 !~ /^(lo|tailscale|docker|podman|br-|veth|cni|virbr|wg|tun|tap)/ && $4 !~ /^(fd|fc)/ {sub(/\/.*/, "", $4); print length($4), $4}' \
  | sort -n | awk 'NR==1 {print $2}' || true)
nixos_ver=$(cat /run/current-system/nixos-version 2>/dev/null || true)
gen_link=$(readlink /nix/var/nix/profiles/system 2>/dev/null || true)
gen_num=$(printf '%s' "$gen_link" | sed -n 's/^system-\([0-9]*\)-link$/\1/p')
gen_str=""
if [ -n "$gen_num" ]; then
  gen_ts=$(stat -c %Y "/nix/var/nix/profiles/$gen_link" 2>/dev/null || true)
  gen_date=$([ -n "$gen_ts" ] && date -d "@$gen_ts" +%Y-%m-%d 2>/dev/null || true)
  if [ -n "$gen_date" ]; then
    gen_str="#$gen_num ($gen_date)"
  else
    gen_str="#$gen_num"
  fi
fi

jq -n \
  --arg cpu "$cpu" \
  --arg ipv4 "$ipv4" \
  --arg ipv6 "$ipv6" \
  --arg nixos_ver "$nixos_ver" \
  --arg gen_str "$gen_str" \
  '{
    info: [
      (if $cpu != "" then { key: "cpu_model", label: "CPU Model", group: "system", value: $cpu } else empty end),
      (if $ipv4 != "" then { key: "ipv4", label: "IPv4", group: "network", value: $ipv4 } else empty end),
      (if $ipv6 != "" then { key: "ipv6", label: "IPv6", group: "network", value: $ipv6 } else empty end),
      (if $nixos_ver != "" then { key: "nixos_version", label: "NixOS", group: "system", value: $nixos_ver } else empty end),
      (if $gen_str != "" then { key: "generation", label: "Generation", group: "system", value: $gen_str } else empty end)
    ]
  }'
