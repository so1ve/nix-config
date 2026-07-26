waydroid_bin=$(command -v waydroid)
udevadm_bin=$(command -v udevadm)

if ! "$waydroid_bin" status | grep -q $'^Session:\tRUNNING$'; then
  echo "Start the Waydroid session before refreshing controllers." >&2
  exit 1
fi

trigger_args=(
  --action=add
  --subsystem-match=input
  --sysname-match=event\*
  --property-match=ID_INPUT_JOYSTICK=1
)

devices=$("$udevadm_bin" trigger --dry-run --verbose "${trigger_args[@]}")
if [[ -z "$devices" ]]; then
  echo "No connected game controllers were found." >&2
  exit 1
fi

echo "$devices"
exec /run/wrappers/bin/pkexec "$udevadm_bin" trigger "${trigger_args[@]}"
