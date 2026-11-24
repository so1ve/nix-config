# Sourced by the packaged browser wrapper, before Chrome starts.
# Different user-data directories can contain profiles with the same name.
# Keep their generated entries, icons, and menu configuration inside the profile.
chrome_user_data_dir="${CHROME_USER_DATA_DIR:-}"
chrome_read_user_data_dir=false
chrome_headless=false
for chrome_argument in "$@"; do
  if "$chrome_read_user_data_dir"; then
    chrome_user_data_dir="$chrome_argument"
    chrome_read_user_data_dir=false
  else
    case "$chrome_argument" in
      --user-data-dir=*) chrome_user_data_dir="${chrome_argument#--user-data-dir=}" ;;
      --user-data-dir) chrome_read_user_data_dir=true ;;
      --headless|--headless=*|-headless|-headless=*) chrome_headless=true ;;
      --) break ;;
    esac
  fi
done

chrome_config_home="${CHROME_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}"
chrome_isolation_root=""
if [[ -n "$chrome_user_data_dir" ]]; then
  chrome_user_data_dir="$(realpath -m -- "$chrome_user_data_dir")"
  chrome_default_user_data_dir="$chrome_config_home/google-chrome"
  if [[ "$chrome_user_data_dir" != "$(realpath -m -- "$chrome_default_user_data_dir")" ]]; then
    chrome_isolation_root="$chrome_user_data_dir"
  fi
elif "$chrome_headless"; then
  chrome_isolation_root="$(realpath -m -- "$chrome_config_home/google-chrome-headless")"
  export CHROME_CONFIG_HOME="$chrome_config_home"
fi

if [[ -n "$chrome_isolation_root" ]]; then
  export XDG_DATA_HOME="$chrome_isolation_root/.local/share"
  export XDG_CONFIG_HOME="$chrome_isolation_root/.config"
fi
