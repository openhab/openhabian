#!/usr/bin/env bats

load packages
load helpers

setup_file() {
  export BASEDIR="${BATS_TEST_DIRNAME}/.."
}

teardown_file() {
  unset BASEDIR
  systemctl stop homegear.service || true
  systemctl stop mosquitto.service || true
}

@test "destructive-homegear_install" {
  echo -e "# \e[36mHomegear installation starting...\e[0m" >&3
  run homegear_setup
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mHomegear installation successful.\e[0m" >&3
  run systemctl is-active --quiet homegear.service
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mHomegear service is running.\e[0m" >&3
}

@test "destructive-mqtt_install" {
  echo -e "# \e[36mMQTT installation starting...\e[0m" >&3
  run mqtt_setup
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mMQTT installation successful.\e[0m" >&3
  run systemctl is-active --quiet mosquitto.service
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mMQTT service is running.\e[0m" >&3
}
