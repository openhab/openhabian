#!/usr/bin/env bats

load nodejs-apps.bash
load helpers.bash
load openhab.bash

setup_file() {
  export BASEDIR="${BATS_TEST_DIRNAME}/.."
  mkdir -p /var/log/openhab
  setfacl -R -m g::rwX /var/log/openhab
}

teardown_file() {
  unset BASEDIR
  systemctl kill frontail.service || true
}

@test "installation-frontail_install" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Frontail installation starting...${COL_DEF}" >&3
  run frontail_setup 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Frontail installation successful.${COL_DEF}" >&3

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if Frontail service is running...${COL_DEF}" >&3
  run systemctl is-active --quiet frontail.service
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Frontail service is running.${COL_DEF}" >&3
}
