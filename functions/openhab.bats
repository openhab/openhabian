#!/usr/bin/env bats

load openhab.bash
load helpers.bash

setup() {
  OPENHAB_CONF="$(mktemp -d)"
  export OPENHAB_CONF
  mkdir -p "${OPENHAB_CONF}/services"
  echo "org.openhab.core:keep=me" > "${OPENHAB_CONF}/services/runtime.cfg"
  openhab_is_installed() { return 0; }
}

teardown() {
  rm -rf "$OPENHAB_CONF"
}

@test "unit-dashboard_add_tile" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Dashboard tile unit test starting...${COL_DEF}" >&3
  run dashboard_add_tile openhabiandocs
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  run dashboard_add_tile openhabiandocs
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  [ "$(grep -c '^org\.openhab\.core\.ui\.tiles:openhabiandocs-link-name=' "${OPENHAB_CONF}/services/runtime.cfg")" -eq 1 ]
  [ "$(grep -c '^org\.openhab\.core\.ui\.tiles:openhabiandocs-link-imageurl=' "${OPENHAB_CONF}/services/runtime.cfg")" -eq 1 ]
  grep -qs '^org\.openhab\.core:keep=me$' "${OPENHAB_CONF}/services/runtime.cfg"
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Dashboard tile is replaced, not duplicated.${COL_DEF}" >&3
}
