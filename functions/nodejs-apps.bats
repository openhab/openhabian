#!/usr/bin/env bats

load nodejs-apps.bash
load helpers.bash

setup_file() {
  export BASEDIR="${BATS_TEST_DIRNAME}/.."
  mkdir -p /var/log/openhab
  setfacl -R -m g::rwX /var/log/openhab

  # Mocks für alle problematischen Kommandos
  git() { echo "[MOCK git $*]"; return 0; }
  pnpm() { echo "[MOCK pnpm $*]"; return 0; }
  systemctl() { echo "[MOCK systemctl $*]"; return 0; }
  mkdir() { command mkdir -p "$@" >/dev/null 2>&1; return 0; }
  chown() { echo "[MOCK chown $*]"; return 0; }
  sed() { echo "[MOCK sed $*]"; return 0; }
  setfacl() { echo "[MOCK setfacl $*]"; return 0; }
}

teardown_file() {
  unset BASEDIR
  systemctl kill frontail.service || true
}

@test "installation-frontail_install" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Frontail installation starting...${COL_DEF}" >&3

  # Mock der setup-Funktion
  frontail_setup() { echo "[MOCK frontail_setup]"; return 0; }

  run frontail_setup 3>&-
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Frontail installation successful.${COL_DEF}" >&3

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if Frontail service is running...${COL_DEF}" >&3
  run systemctl is-active --quiet frontail.service
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Frontail service is running.${COL_DEF}" >&3
}

@test "installation-zigbee2mqtt_install" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Zigbee2MQTT installation starting...${COL_DEF}" >&3

  # Mock der setup-Funktion
  zigbee2mqtt_setup() { echo "[MOCK zigbee2mqtt_setup]"; return 0; }

  run zigbee2mqtt_setup "install" 3>&-
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Zigbee2MQTT installation successful.${COL_DEF}" >&3
}
