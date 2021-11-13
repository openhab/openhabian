#!/usr/bin/env bats

load influxdb+grafana.bash
load helpers.bash

setup_file() {
  export DEBIAN_FRONTEND="noninteractive"
}

teardown_file() {
  systemctl kill influxdb.service || true
  systemctl kill grafana-server.service || true
}

@test "destructive-influxDB_install" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] InfluxDB installation starting...${COL_DEF}" >&3
  run influxdb_install "admin" "Password1234" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] InfluxDB installation successful.${COL_DEF}" >&3

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if InfluxDB service is running...${COL_DEF}" >&3
  run systemctl is-active --quiet influxdb.service
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] InfluxDB service is running.${COL_DEF}" >&3

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if InfluxDB service is responding...${COL_DEF}" >&3
  run curl --retry 6 --retry-connrefused --user "admin:Password1234" --insecure "http://localhost:8086/query" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] InfluxDB service is responding.${COL_DEF}" >&3
}

@test "destructive-grafana_install" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Grafana installation starting...${COL_DEF}" >&3
  run grafana_install "Password1234" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Grafana installation successful.${COL_DEF}" >&3

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Grafana parameter allow_embedding...${COL_DEF}" >&3
  run grep -q -e "^allow_embedding = true" /etc/grafana/grafana.ini
  if [ "$status" -ne 0 ]; then echo -e "# ${COL_RED}$(timestamp) [openHABian] Grafana parameter allow_embedding missing.${COL_DEF}" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Grafana parameter allow_embedding successful.${COL_DEF}" >&3

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if Grafana service is running...${COL_DEF}" >&3
  run systemctl is-active --quiet grafana-server.service
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Grafana service is running.${COL_DEF}" >&3

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Changing Grafana settings...${COL_DEF}" >&3
  run curl --retry 6 --retry-connrefused --user "admin:Password1234" --header "Content-Type: application/json" --request PUT --data "{\"password\":\"Password234\"}" "http://localhost:3000/api/admin/users/1/password"
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Grafana settings successfully changed.${COL_DEF}" >&3

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Starting reinstallation of Grafana...${COL_DEF}" >&3
  run grafana_install "Password3456" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Grafana reinstallation successful.${COL_DEF}" >&3

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Changing Grafana settings...${COL_DEF}" >&3
  run curl --retry 6 --retry-connrefused --user "admin:Password3456" --header "Content-Type: application/json" --request PUT --data "{\"password\":\"Password234\"}" "http://localhost:3000/api/admin/users/1/password"
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Grafana settings successfully changed.${COL_DEF}" >&3
}
