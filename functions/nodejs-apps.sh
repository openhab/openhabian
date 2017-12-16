#!/usr/bin/env bash

nodejs_setup() {
  if command -v npm &>/dev/null; then
    return 0
  else
    FAILED=0
    if is_armv6l; then
      echo -n "$(timestamp) [openHABian] Install Node.js for Armv6 (prerequisite for other packages)... "
      f=$(wget -qO- https://nodejs.org/download/release/latest-boron/ | grep "armv6l.tar.gz" | cut -d '"' -f 2)
      cond_redirect wget -q -O /tmp/nodejs-armv6.tgz https://nodejs.org/download/release/latest-boron/$f 2>&1 || FAILED=1
      if [ $FAILED -eq 1 ]; then echo "FAILED (nodejs preparations)"; exit 1; fi
      # unpack it into the correct places
      cond_redirect tar -zxf /tmp/nodejs-armv6.tgz --strip-components=1 -C /usr 2>&1
      cond_redirect rm /tmp/nodejs-armv6.tgz 2>&1
    else
      echo -n "$(timestamp) [openHABian] Installing Node.js (prerequisite for other packages)... "
      cond_redirect wget -O /tmp/nodejs-v7.x.sh https://deb.nodesource.com/setup_7.x || FAILED=1
      cond_redirect bash /tmp/nodejs-v7.x.sh || FAILED=1
      if [ $FAILED -eq 1 ]; then echo "FAILED (nodejs preparations)"; exit 1; fi
      #cond_redirect apt update # part of the node script above
      cond_redirect apt -y install nodejs
      if [ $? -ne 0 ]; then echo "FAILED (nodejs installation)"; exit 1; fi
    fi
    if command -v npm &>/dev/null; then echo "OK"; else echo "FAILED (service)"; exit 1; fi
  fi
}

frontail_setup() {
  nodejs_setup
  echo -n "$(timestamp) [openHABian] Installing the openHAB Log Viewer (frontail)... "
  cond_redirect npm install -g frontail
  if [ $? -ne 0 ]; then echo "FAILED (frontail)"; exit 1; fi
  cond_redirect npm update -g frontail
  #
  frontail_base="/usr/lib/node_modules/frontail"
  cp $BASEDIR/includes/frontail-preset.json $frontail_base/preset/openhab.json
  cp $BASEDIR/includes/frontail-theme.css $frontail_base/lib/web/assets/styles/openhab.css
  cp $BASEDIR/includes/frontail.service /etc/systemd/system/frontail.service
  chmod 664 /etc/systemd/system/frontail.service
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable frontail.service
  cond_redirect systemctl restart frontail.service
  if [ $? -ne 0 ]; then echo "FAILED (service)"; exit 1; fi
  dashboard_add_tile frontail
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED (dashboard tile)"; exit 1; fi
}

nodered_setup() {
  nodejs_setup
  echo -n "$(timestamp) [openHABian] Installing Node-RED... "
  FAILED=0
  cond_redirect wget -O /tmp/update-nodejs-and-nodered.sh https://raw.githubusercontent.com/node-red/raspbian-deb-package/master/resources/update-nodejs-and-nodered || FAILED=1
  cond_redirect bash /tmp/update-nodejs-and-nodered.sh || FAILED=1
  if [ $FAILED -eq 1 ]; then echo "FAILED (nodered)"; exit 1; fi
  cond_redirect npm install -g node-red-contrib-bigtimer
  if [ $? -ne 0 ]; then echo "FAILED (nodered bigtimer addon)"; exit 1; fi
  cond_redirect npm update -g node-red-contrib-bigtimer
  cond_redirect npm install -g node-red-contrib-openhab2
  if [ $? -ne 0 ]; then echo "FAILED (nodered openhab2 addon)"; exit 1; fi
  cond_redirect npm update -g node-red-contrib-openhab2
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable nodered.service
  cond_redirect systemctl restart nodered.service
  if [ $? -ne 0 ]; then echo "FAILED (service)"; exit 1; fi
  dashboard_add_tile nodered
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED (dashboard tile)"; exit 1; fi
}

yo_generator_setup() {
  nodejs_setup
  echo -n "$(timestamp) [openHABian] Installing the Yeoman openHAB generator... "
  cond_redirect npm install -g yo generator-openhab
  if [ $? -ne 0 ]; then echo "FAILED (yo_generator)"; exit 1; fi
  cond_redirect npm update -g generator-openhab
}
