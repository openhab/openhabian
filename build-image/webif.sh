#!/bin/bash
# start:     	starts a minimalistic web server
# 	    	shows the status of OpenHABianPi installation
# restart:   	checks if webserver is running 
# inst_done: 	create finish message and link to http://$hostname:8080
# cleanup:	stops the webserver
#	     	removes all no longer needed files

port=80 # Port the webserver is listing to
source /etc/openhabian.conf # to get the hostname

if [ $1 = "start" ]; then
  mkdir /tmp/webif
  ln -s /boot/first-boot.log /tmp/webif/first-boot.txt
  echo "<html>
        <head>
        <title>openHABian</title>
        <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
        <meta http-equiv="Pragma" content="no-cache" />
        <meta http-equiv="Expires" content="0" />
        </head>" > /tmp/webif/index.html
  echo "<body>
        <h1>openHABian Installation Status</h1>
        the log will be refreshed automatically every 10 seconds
        <iframe src="http://$hostname:$port/first-boot.txt" scrolling="yes" width="100%" height="90%"></iframe>
        </body>
        </html>" >> /tmp/webif/index.html
  (cd /tmp/webif; python3 -m http.server $port > /dev/null 2>&1 &)
fi

if [ $1 = "reinsure_running" ]; then
  webifrunning=$(ps -ef | pgrep python3)
  if [ -z $webifrunning ]; then
    python3 -m http.server $port > /dev/null 2>&1 &
  fi
fi

if [ $1 = "inst_done" ]; then
  echo "<html>
        <head>
        <title>openHABian</title>
        </head>" > index.html
  echo "<body>
        <h1>openHABian Installation Status</h1>
        Installation successful. You can now access the openHAB dashboard using <a href="http://$hostname:8080">this link</a>
        </body>
        </html>" > /tmp/webif/index.html
fi

if [ $1 = "cleanup" ]; then
  kill $(ps -ef | pgrep python3) > /dev/null && rm -R /tmp/webif > /dev/null
  rm /boot/webif.sh > /dev/null
fi

