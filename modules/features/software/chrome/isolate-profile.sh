# Sourced by the packaged browser wrapper, before Chrome starts.
# Different user-data directories can contain profiles with the same name.
# Keep their generated entries, icons, and menu configuration inside the profile.
chrome_user_data_dir="${CHROME_USER_DATA_DIR:-}"
chrome_read_user_data_dir=false
for chrome_argument in "$@"; do
  if "$chrome_read_user_data_dir"; then
    chrome_user_data_dir="$chrome_argument"
    chrome_read_user_data_dir=false
  else
    case "$chrome_argument" in
      --user-data-dir=*) chrome_user_data_dir="${chrome_argument#--user-data-dir=}" ;;
      --user-data-dir) chrome_read_user_data_dir=true ;;
      --) break ;;
    esac
  fi
done

if [[ -n "$chrome_user_data_dir" ]]; then
  chrome_user_data_dir="$(realpath -m -- "$chrome_user_data_dir")"
  chrome_default_user_data_dir="${CHROME_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}/google-chrome"
  if [[ "$chrome_user_data_dir" != "$(realpath -m -- "$chrome_default_user_data_dir")" ]]; then
    export XDG_DATA_HOME="$chrome_user_data_dir/.local/share"
    export XDG_CONFIG_HOME="$chrome_user_data_dir/.config"
  fi
fi
