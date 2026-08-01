compose_file="${XDG_CONFIG_HOME:-$HOME/.config}/winapps/compose.yaml"

compose() {
  podman-compose --file "$compose_file" "$@"
}

case "${1:-}" in
  start)
    compose up -d
    ;;
  stop)
    compose stop
    ;;
  restart)
    compose restart
    ;;
  status)
    if podman container exists WinApps; then
      podman ps --all --filter name='^WinApps$' --format 'table {{.Names}}\t{{.Status}}'
    else
      echo 'WinApps container does not exist.'
    fi
    ;;
  logs)
    if ! podman container exists WinApps; then
      echo 'WinApps container does not exist.' >&2
      exit 1
    fi
    exec podman logs --follow WinApps
    ;;
  desktop)
    compose up -d
    exec winapps windows
    ;;
  *)
    echo 'Usage: winapps-vm {start|stop|restart|status|logs|desktop}' >&2
    exit 2
    ;;
esac
