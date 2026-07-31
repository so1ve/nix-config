pkgs:

pkgs.writeShellApplication {
  name = "focus-or-launch";
  runtimeInputs = with pkgs; [
    jq
    niri
  ];
  text = ''
    if [ "$#" -lt 2 ]; then
      echo "Usage: focus-or-launch <app-id> <command> [argument...]" >&2
      exit 2
    fi

    app_id="$1"
    shift

    window_id=""
    if windows="$(niri msg -j windows 2>/dev/null)"; then
      window_id="$(
        printf '%s\n' "$windows" \
          | jq -r --arg app_id "$app_id" \
              '[.[] | select(.app_id == $app_id) | .id] | first // empty'
      )"
    fi

    if [ -n "$window_id" ] \
      && niri msg action focus-window --id "$window_id" >/dev/null 2>&1; then
      exit 0
    fi

    exec "$@"
  '';
}
