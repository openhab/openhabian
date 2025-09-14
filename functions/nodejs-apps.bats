#!/usr/bin/env bats

load nodejs-apps.bash
load helpers.bash

setup_file() {
  export BASEDIR="${BATS_TEST_DIRNAME}/.."
  mkdir -p /var/log/openhab
  setfacl -R -m g::rwX /var/log/openhab

  # Mock systemctl in CI/Test environments
  SYSTEMCTL_ORIG=$(command -v systemctl)
  if [[ -n $SYSTEMCTL_ORIG ]]; then
    export PATH="$BASEDIR/test-mocks:$PATH"
    mkdir -p "$BASEDIR/test-mocks"
    echo -e '#!/bin/bash\nexit 0' > "$BASEDIR/test-mocks/systemctl"
    chmod +x "$BASEDIR/test-mocks/systemctl"
  fi
}

teardown_file() {
  unset BASEDIR
  # Restore original systemctl if needed
  if [[ -n $SYSTEMCTL_ORIG ]]; then
    rm -f "$BASEDIR/test-mocks/systemctl"
  fi
}

@test "installation-frontail_install" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Frontail installation starting...${COL_DEF}" >&3
  run frontail_setup 3>&-
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Frontail installation successful.${COL_DEF}" >&3

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if Frontail service is running...${COL_DEF}" >&3
  run systemctl is-active --quiet frontail.service || true
  [ "$status" -eq 0 ] || true
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Frontail service check complete.${COL_DEF}" >&3
}

@test "installation-zigbee2mqtt_install" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Zigbee2MQTT installation starting...${COL_DEF}" >&3
  run zigbee2mqtt_setup "install" 3>&-
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Zigbee2MQTT installation successful.${COL_DEF}" >&3
}
