#!/bin/bash
## start:  Starts a minimalistic web server that shows the status of the
##       openHABian installation.
## restart:  Checks if webserver is running.
## inst_done:  Create finish message and link to http://$hostname:8080.
## cleanup:  Stops the webserver and removes all no longer needed files.

port=80 # Port the webserver is listing to
# shellcheck source=/etc/openhabian.conf disable=SC1091
source /etc/openhabian.conf # to get the hostname

if [ "$1" = "start" ]; then
  mkdir -p /tmp/webif
  ln -s /boot/first-boot.log /tmp/webif/first-boot.txt
  # shellcheck disable=SC2016
  echo '<html>
<head>
<title>openHABian</title>
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
<meta http-equiv="Pragma" content="no-cache" />
<meta http-equiv="Expires" content="0" />
<meta http-equiv="Refresh" content="10" />
</head>' > /tmp/webif/index.html
  # shellcheck disable=SC2016
  echo '<body>
<h1>openHABian Installation Status</h1>
the log will be refreshed automatically every 10 seconds
<iframe src='"/first-boot.txt"' scrolling="yes" width="100%" height="90%"></iframe>
</body>
</html>' >> /tmp/webif/index.html
  (cd /tmp/webif || exit 1; python3 -m http.server $port &> /dev/null &)
fi

# changed to python3 due to issues in automated testing
if [ "$1" = "reinsure_running" ]; then
  webifrunning=$(ps -ef | pgrep python3)
  if [ -z "$webifrunning" ]; then
    python3 -m http.server $port &> /dev/null &
  fi
fi

if [ "$1" = "inst_done" ]; then
  # dir was eventually deleted by reboot
  mkdir -p /tmp/webif
  # shellcheck disable=SC2016
  echo '<html>
<head>
<meta http-equiv='"refresh"' content='"10;url=http://${HOSTNAME:-$hostname}:8080/"' />
<title>openHABian</title>
</head>' > /tmp/webif/index.html
  echo '<body>
<h1>openHABian Installation Status</h1>
Installation successful. You can now access the openHAB dashboard using <a href='"http://${HOSTNAME:-$hostname}:8080"'>this link</a>
</body>
</html>' >> /tmp/webif/index.html
fi

if [ "$1" = "cleanup" ]; then
  webifrunning=$(ps -ef | pgrep python3)
  if [ -n "$webifrunning" ]; then
    kill "$webifrunning" > /dev/null
  fi
  rm -R /tmp/webif > /dev/null
  rm /boot/webif.bash > /dev/null
fi
