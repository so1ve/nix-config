failed=$(systemctl list-units --state=failed --no-legend --plain | awk '{print $1}')
if [ -z "$failed" ]; then
  echo "0 failed units"
  exit 0
fi

echo "failed: $(printf '%s\n' "$failed" | paste -sd, -)"
exit 1
