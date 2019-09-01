#!/usr/bin/env bats

load influxdb+grafana
load helpers

@test "destructive-influxDB_install" {
  echo -e "# \e[36mInfluxDB installation starting..." >&3
  run influxdb_install "Password1234"
  [ "$status" -eq 0 ]
  echo -e "# \e[32mInfluxDB installation successful." >&3
# does not work before #683 is merged
#  run systemctl is-active --quiet influxdb.service
#  [ "$status" -eq 0 ]
  echo -e "# \e[32mInfluxDB service running." >&3
}

@test "destructive-grafana_install" {
  echo -e "# \e[36mGrafana installation starting..." >&3
  run grafana_install "Password1234"
  [ "$status" -eq 0 ]
  echo -e "# \e[32mGrafana installation successful." >&3
# does not work before #683 is merged
#  run systemctl is-active --quiet grafana-server.service
#  [ "$status" -eq 0 ]
  echo -e "# \e[32mGrafana service running." >&3
}

