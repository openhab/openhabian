#!/usr/bin/env bats

load packages.bash
load helpers.bash

setup_file() {
  export BASEDIR="${BATS_TEST_DIRNAME}/.."
}

teardown_file() {
  unset BASEDIR
  systemctl kill homegear.service || true
  systemctl kill mosquitto.service || true
  systemctl kill grott.service || true
}

@test "destructive-homegear_install" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Homegear installation starting...${COL_DEF}" >&3
  run homegear_setup 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Homegear installation successful.${COL_DEF}" >&3

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if Homegear service is running...${COL_DEF}" >&3
  run systemctl is-active --quiet homegear.service
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Homegear service is running.${COL_DEF}" >&3
}

@test "destructive-mqtt_install" {
  if is_aarch64; then skip "Not executing MQTT test because it currently does not support aarch64/arm64 env provided by GitHub Actions."; fi

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] MQTT installation starting...${COL_DEF}" >&3
  run mqtt_setup 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] MQTT installation successful.${COL_DEF}" >&3

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if MQTT service is running...${COL_DEF}" >&3
  run systemctl is-active --quiet mosquitto.service
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] MQTT service is running.${COL_DEF}" >&3
}

@test "destructive-knxd_install" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] knxd installation starting...${COL_DEF}" >&3
  run knxd_setup 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] knxd installation successful.${COL_DEF}" >&3

  # knxd service must be configured and is not started automatically, but we can call knxd executable
  run knxd --version 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] knxd executable ok.${COL_DEF}" >&3
}

@test "destructive-1wire_install" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] 1wire installation starting...${COL_DEF}" >&3
  run 1wire_setup 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] 1wire installation successful.${COL_DEF}" >&3
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

@test "destructive-grott_install" {
  ## Confirm Grott Proxy install completes without error
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Grott Proxy installation starting...${COL_DEF}" >&3
  run install_grott "install" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Grott Proxy installation successful.${COL_DEF}" >&3

  ## Confirm Grott service is running
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if Grott Proxy service is running...${COL_DEF}" >&3
  run systemctl is-active --quiet grott
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Grott Proxy service is running.${COL_DEF}" >&3
}
