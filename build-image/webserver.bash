#!/usr/bin/env bash

## start:             Starts a minimalistic web server that shows the status of the
##                    openHABian installation.
## reinsure_running:  Checks if webserver is running.
## inst_done:         Create finish message and link to http://${hostname:-openhabian}:8080.
## cleanup:           Stops the webserver and removes all no longer needed files.

port="81"
isWebRunning="$(ps -ef | pgrep python3)"

if [[ "$1" = "start" ]]; then
  mkdir -p "${TMPDIR:-/tmp}"/webserver
  ln -sf /boot/first-boot.log "${TMPDIR:-/tmp}"/webserver/first-boot.txt
  cp /opt/openhabian/includes/webserver/install-log.html "${TMPDIR:-/tmp}"/webserver/index.html
  (cd "${TMPDIR:-/tmp}"/webserver || exit 1; python3 -m http.server "$port" &> /dev/null &)
fi

if [[ $1 == "reinsure_running" ]]; then
  if [[ -z $isWebRunning ]]; then
    (cd "${TMPDIR:-/tmp}"/webserver || exit 1; python3 -m http.server "$port" &> /dev/null &)
  fi
fi

if [[ $1 == "inst_done" ]]; then
  mkdir -p "${TMPDIR:-/tmp}"/webserver
  sed 's|%HOSTNAME|'"${HOSTNAME:-openhabian}"'|g' /opt/openhabian/includes/webserver/install-complete.html > "${TMPDIR:-/tmp}"/webserver/index.html
fi

if [[ $1 == "cleanup" ]]; then
  if [[ -n $isWebRunning ]]; then
    kill "$isWebRunning" &> /dev/null
  fi
  rm -rf "${TMPDIR:-/tmp}"/webserver &> /dev/null
  rm -f /boot/webserver.bash &> /dev/null
fi
