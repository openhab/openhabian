#!/usr/bin/env bats

load 'grott-install.bash'
load 'helpers.bash'

setup_file() {
  export BASEDIR="${BATS_TEST_DIRNAME}/.."
}

teardown_file() {
  unset BASEDIR
  # Stop grott.service
  systemctl kill grott.service || true
}

@test "destructive-grott_install" {
  ## Install Grott Proxy
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Grott Proxy installation starting...${COL_DEF}" >&3
  run install_grott "install" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Grott Proxy installation successful.${COL_DEF}" >&3

  # Wait for grott.service start
  sleep 5s

  ## Check grott.service is running
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if Grott Proxy service is running...${COL_DEF}" >&3
  run systemctl is-active --quiet grott.service
  if [ "$status" -ne 0 ]; then systemctl status grott.service; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Grott Proxy service is running.${COL_DEF}" >&3
}
