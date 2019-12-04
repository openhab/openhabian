#!/usr/bin/env bash

nodejs_setup() {
  if command -v npm &>/dev/null; then
    return 0
  fi
  FAILED=0

  if is_armv6l; then f=$(wget -qO- https://nodejs.org/download/release/latest-dubnium/ | grep "armv6l.tar.gz" | cut -d '"' -f 2); fi
  if is_armv7l; then f=$(wget -qO- https://nodejs.org/download/release/latest-dubnium/ | grep "armv7l.tar.gz" | cut -d '"' -f 2); fi
  if is_aarch64; then f=$(wget -qO- https://nodejs.org/download/release/latest-dubnium/ | grep "arm64.tar.gz" | cut -d '"' -f 2); fi

  if is_arm; then
    echo -n "$(timestamp) [openHABian] Installing Node.js for arm (prerequisite for other packages)... "
    cond_redirect wget -O /tmp/nodejs-arm.tar.gz "https://nodejs.org/download/release/latest-dubnium/$f" 2>&1 || FAILED=1
    if [ $FAILED -eq 1 ]; then echo "FAILED (nodejs preparations)"; exit 1; fi
    cond_redirect tar -zxf /tmp/nodejs-arm.tar.gz --strip-components=1 -C /usr 2>&1
    cond_redirect rm /tmp/nodejs-arm.tar.gz 2>&1
  else
    echo -n "$(timestamp) [openHABian] Installing Node.js (prerequisite for other packages)... "
    cond_redirect wget -O /tmp/nodejs-setup.sh https://deb.nodesource.com/setup_10.x || FAILED=1
    cond_redirect bash /tmp/nodejs-setup.sh || FAILED=1
    if [ $FAILED -eq 1 ]; then echo "FAILED (nodejs preparations)"; exit 1; fi
    if ! cond_redirect apt-get -y install nodejs; then echo "FAILED (nodejs installation)"; exit 1; fi
  fi
  if command -v npm &>/dev/null; then echo "OK"; else echo "FAILED (service)"; exit 1; fi
}

frontail_setup() {
  nodejs_setup
  # set frontail install directory relative to npm (nodejs) base
  node_base=$(npm list -g|head -n 1)
  echo -n "$(timestamp) [openHABian] Installing the openHAB Log Viewer (frontail) relative to nodejs base ${node_base}... "
  frontail_base="${node_base}/node_modules/frontail"
  # clear frontail install dir if it exists, otherwise npm install will fail, #647
  if [ -d "$frontail_base" ]; then 
    cond_redirect npm uninstall -g frontail
  fi
  if ! cond_redirect npm install -g frontail; then echo "FAILED (frontail)"; exit 1; fi
  cond_redirect npm update -g frontail
  #
  mkdir -p ${frontail_base}/preset ${frontail_base}/web/assets/styles
  
  cp "$BASEDIR"/includes/frontail-preset.json $frontail_base/preset/openhab.json
  cp "$BASEDIR"/includes/frontail-theme.css $frontail_base/web/assets/styles/openhab.css
  sed -e "s|%FRONTAILBASE|${frontail_base}|g" ${BASEDIR}/includes/frontail.service > /etc/systemd/system/frontail.service
  chmod 664 /etc/systemd/system/frontail.service
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable frontail.service
  if cond_redirect systemctl restart frontail; then echo "OK"; else echo "FAILED (service)"; exit 1; fi
  dashboard_add_tile frontail
}

nodered_setup() {
  echo -n "$(timestamp) [openHABian] Installing Node-RED... "
  FAILED=0
  cond_redirect wget -O /tmp/update-nodejs-and-nodered.sh https://raw.githubusercontent.com/node-red/raspbian-deb-package/master/resources/update-nodejs-and-nodered || FAILED=1
  cond_redirect chmod +x /tmp/update-nodejs-and-nodered.sh || FAILED=1
  cond_redirect /usr/bin/sudo -u "${username:-openhabian}" -H sh -c "/tmp/update-nodejs-and-nodered.sh" || FAILED=1
  if [ $FAILED -eq 1 ]; then echo "FAILED (nodered)"; exit 1; fi
  if ! cond_redirect npm install -g node-red-contrib-bigtimer; then echo "FAILED (nodered bigtimer addon)"; exit 1; fi
  cond_redirect npm update -g node-red-contrib-bigtimer
  if ! cond_redirect npm install -g node-red-contrib-openhab2; then echo "FAILED (nodered openhab2 addon)"; exit 1; fi
  cond_redirect npm update -g node-red-contrib-openhab2
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable nodered.service
  if cond_redirect systemctl restart nodered.service; then echo "OK"; else echo "FAILED (service)"; exit 1; fi
  dashboard_add_tile nodered
}
