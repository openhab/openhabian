#!/usr/bin/env bash

## start:             Starts a minimalistic web server that shows the status of the
##                    openHABian installation.
## reinsure_running:  Checks if webserver is running.
## inst_done:         Create finish message and link to http://${HOSTNAME:-openhab}:8080.
## cleanup:           Stops the webserver and removes all no longer needed files.

port="80"
isWebRunning="$(ps -ef | pgrep python3)"

if [[ "$1" = "start" ]]; then
  mkdir -p /tmp/webserver
  ln -sf /boot/first-boot.log /tmp/webserver/first-boot.txt
  cp /opt/openhabian/includes/install-log.html /tmp/webserver/index.html
  (cd /tmp/webserver || exit 1; python3 -m http.server "$port" &> /dev/null &)
fi

if [[ $1 == "reinsure_running" ]]; then
  if [[ -z $isWebRunning ]]; then
    (cd /tmp/webserver || exit 1; python3 -m http.server "$port" &> /dev/null &)
  fi
fi

if [[ $1 == "inst_done" ]]; then
  sed 's|%HOSTNAME|'"${HOSTNAME:-openhab}"'|g' /opt/openhabian/includes/install-complete.html > /tmp/webserver/index.html
fi

if [[ $1 == "cleanup" ]]; then
  if [[ -n $isWebRunning ]]; then
    kill "$isWebRunning" &> /dev/null
  fi
  rm -rf /tmp/webserver &> /dev/null
  rm -f /boot/webserver.bash &> /dev/null
fi
