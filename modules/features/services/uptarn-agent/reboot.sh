booted=$(readlink -f /run/booted-system/kernel)
current=$(readlink -f /run/current-system/kernel)
if [ "$booted" = "$current" ]; then
  echo "up to date"
  exit 0
fi

echo "reboot required"
echo "booted:  $booted"
echo "current: $current"
exit 2
