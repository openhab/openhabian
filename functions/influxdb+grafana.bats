#!/usr/bin/env bats

load influxdb+grafana
load helpers

@test "destructive-influxDB_install" {
  run influxdb_install "Password1234"
  [ "$status" -eq 0 ]
  echo -e "# \e[32mInfluxDB installation successful." >&3
  run systemctl is-active --quiet influxdb.service
  [ "$status" -eq 0 ]
  echo -e "# \e[32mInfluxDB service running." >&3
}

@test "destructive-grafana_install" {
  run grafana_install "Password1234"
  [ "$status" -eq 0 ]
  echo -e "# \e[32mGrafana installation successful." >&3
  run systemctl is-active --quiet grafana-server.service
  [ "$status" -eq 0 ]
  echo -e "# \e[32mGrafana service running." >&3
}
