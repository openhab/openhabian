#!/usr/bin/env bats

load nodejs-apps.bash
load helpers.bash
load openhab.bash

setup_file() {
  export BASEDIR="${BATS_TEST_DIRNAME}/.."
  mkdir -p /var/log/openhab2
  setfacl -R -m g::rwX /var/log/openhab2
}

teardown_file() {
  unset BASEDIR
  systemctl kill frontail.service || true
}

@test "development-frontail_install" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Frontail installation starting...${COL_DEF}" >&3
  run frontail_setup 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Frontail installation successful.${COL_DEF}" >&3

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if Frontail service is running...${COL_DEF}" >&3
  run journalctl -xu frontail.service
  echo "$output" >&3; fi
  run systemctl status frontail.service >&3
  echo "$output" >&3; fi
  run su - frontail -c  "/usr/lib/node_modules/frontail/bin/frontail --ui-highlight --ui-highlight-preset /usr/lib/node_modules/frontail/preset/openhab.json -t openhab -l 2000 -n 200 /var/log/openhab2/openhab.log &"
  echo "$output" >&3; fi
  run systemctl is-active --quiet frontail.service
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Frontail service is running.${COL_DEF}" >&3
}
