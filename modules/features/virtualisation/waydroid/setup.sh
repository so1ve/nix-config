state_dir=/var/lib/waydroid
config_file="$state_dir/waydroid.cfg"
libndk_file="$state_dir/overlay/system/lib64/libndk_translation.so"
houdini_file="$state_dir/overlay/system/lib64/libhoudini.so"
sudo=/run/wrappers/bin/sudo

waydroid_bin=$(command -v waydroid)
waydroid_script_bin=$(command -v waydroid_script)
crudini_bin=$(command -v crudini)
systemctl_bin=$(command -v systemctl)

root() {
  "$sudo" "$@"
}

property_is() {
  local value
  value=$("$crudini_bin" --get "$config_file" properties "$1") || return 1
  [[ "$value" == "$2" ]]
}

if ((EUID == 0)); then
  echo "Run waydroid-setup as your desktop user; it uses sudo when needed." >&2
  exit 1
fi

if [[ ! -f "$config_file" ]]; then
  echo "Initializing a Vanilla Waydroid image..."
  root "$waydroid_bin" init --system_type VANILLA
else
  system_ota=$("$crudini_bin" --get "$config_file" waydroid system_ota)
  if [[ "$system_ota" != */VANILLA.json ]]; then
    echo "The existing Waydroid image is not Vanilla." >&2
    echo "Refusing to reset /var/lib/waydroid automatically." >&2
    exit 1
  fi
fi

needs_libndk=0
if [[ ! -f "$libndk_file" ]] \
  || ! property_is ro.dalvik.vm.native.bridge libndk_translation.so
then
  needs_libndk=1
fi

has_houdini=0
if [[ -f "$houdini_file" ]] \
  || property_is ro.dalvik.vm.native.bridge libhoudini.so
then
  has_houdini=1
fi

if (( ! needs_libndk && ! has_houdini )) \
  && property_is persist.waydroid.uevent true \
  && property_is persist.waydroid.fake_touch ""
then
  echo "Waydroid is already configured."
  exit 0
fi

container_was_active=0
if "$systemctl_bin" is-active --quiet waydroid-container.service; then
  container_was_active=1
fi

restore_container() {
  if ((container_was_active)); then
    root "$systemctl_bin" start waydroid-container.service
  fi
}
trap restore_container EXIT

"$waydroid_bin" session stop || true
root "$systemctl_bin" stop waydroid-container.service

if ((has_houdini)); then
  echo "Removing expired Houdini ARM translation..."
  root "$waydroid_script_bin" -a 13 uninstall libhoudini
  needs_libndk=1
fi

if ((needs_libndk)); then
  echo "Installing libndk ARM translation..."
  root "$waydroid_script_bin" -a 13 install libndk
fi

root "$crudini_bin" --set \
  "$config_file" properties persist.waydroid.uevent true
root "$crudini_bin" --set \
  "$config_file" properties persist.waydroid.fake_touch ""
root "$waydroid_bin" upgrade --offline

restore_container
trap - EXIT

echo "Waydroid setup is complete. Start Waydroid normally."
echo "For a connected controller, run waydroid-gamepad-refresh after the session starts."
