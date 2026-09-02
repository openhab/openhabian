#!/usr/bin/env bats

load packages.bash
load helpers.bash

setup_file() {
  export BASEDIR="${BATS_TEST_DIRNAME}/.."
}

teardown_file() {
  unset BASEDIR
}


@test "destructive-setup_esphome_device_builder" {
  ## Confirm ESPHome Device builder install completes without error
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] ESPHome Device builder installation starting...${COL_DEF}" >&3
  run setup_esphome_device_builder "install" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] ESPHome Device builder installation successful.${COL_DEF}" >&3

  ## Confirm ESPHome Device builder service is running
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if ESPHome Device builder service is running after installation...${COL_DEF}" >&3
  run systemctl is-active --quiet esphome-device-builder.service
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] ESPHome Device builder service is running after installation.${COL_DEF}" >&3

  ## Confirm ESPHome Device builder update completes without error
  ## Test ist the same as for installation, but the service is already runngin and so th script decided to update the ESPHome Device builder 
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] ESPHome Device builder update starting...${COL_DEF}" >&3
  run setup_esphome_device_builder "install" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] ESPHome Device builder update successful.${COL_DEF}" >&3

  ## Confirm ESPHome Device builder service is running
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if ESPHome Device builder service is running after update...${COL_DEF}" >&3
  run systemctl is-active --quiet esphome-device-builder.service
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] ESPHome Device builder service is running after update.${COL_DEF}" >&3

  ## Confirm ESPHome Device builder uninstall completes without error
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] ESPHome Device builder uninstallation starting...${COL_DEF}" >&3
  run setup_esphome_device_builder "remove" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] ESPHome Device builder uninstallation successful.${COL_DEF}" >&3
}
