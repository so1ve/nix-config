unit=$1
timer=${2:-}

if [ -n "$timer" ]; then
  if ! systemctl is-active --quiet "$timer"; then
    echo "inactive"
    exit 1
  fi
  if systemctl is-failed --quiet "$unit"; then
    echo "failed"
    exit 1
  fi
  echo "active"
  exit 0
fi

if systemctl is-active --quiet "$unit"; then
  echo "active"
  exit 0
fi
if systemctl is-failed --quiet "$unit"; then
  echo "failed"
  exit 1
fi
echo "inactive"
exit 1
