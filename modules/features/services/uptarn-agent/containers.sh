systemctl list-units --type=service --all --no-legend --plain | awk '
  /Podman container / {
    total++
    name = $1
    sub(/\.service$/, "", name)
    if ($3 == "active" && $4 == "running") {
      running++
      ok_list = ok_list (ok_list ? "\n" : "") name ": running"
    } else if ($3 == "activating") {
      starting++
      bad_list = bad_list (bad_list ? "\n" : "") name ": " $3 "/" $4
    } else {
      down++
      bad_list = bad_list (bad_list ? "\n" : "") name ": " $3 "/" $4
    }
  }
  END {
    if (total == 0) {
      print "0 containers"
      exit 0
    }
    if (down > 0) {
      printf "%d/%d running (%d down)\n", running, total, down
      print bad_list
      exit 1
    }
    if (starting > 0) {
      printf "%d/%d running (%d starting)\n", running, total, starting
      print bad_list
      exit 2
    }
    printf "%d/%d running\n", running, total
    print ok_list
  }'
