#!/usr/bin/env bats

load influxdb+grafana
load helpers

@test "destructive-influxDB_install" {
  echo -e "# \e[36mInfluxDB installation starting..." >&3
  run influxdb_install "Password1234"
  [ "$status" -eq 0 ]
  echo -e "# \e[32mInfluxDB installation successful." >&3
  run systemctl is-active --quiet influxdb.service
  [ "$status" -eq 0 ]
  echo -e "# \e[32mInfluxDB service running." >&3
  run curl --retry 5 --retry-connrefused -s --insecure --user "admin:Password1234" "http://localhost:8086/query" >/dev/null
  [ "$status" -eq 0 ]
  echo -e "# \e[32mInfluxDB service is responding." >&3
}

@test "destructive-grafana_install" {
  echo -e "# \e[36mGrafana installation starting..." >&3
  run grafana_install "Password1234"
  [ "$status" -eq 0 ]
  echo -e "# \e[32mGrafana installation successful." >&3
  run systemctl is-active --quiet grafana-server.service
  [ "$status" -eq 0 ]
  echo -e "# \e[32mGrafana service running." >&3
  run curl --retry 5 --retry-connrefused --user admin:Password1234 --header "Content-Type: application/json" --request PUT --data "{\"password\":\"Password234\"}" http://localhost:3000/api/admin/users/1/password
  [ "$status" -eq 0 ]
  echo -e "# \e[32mGrafana settings sucessfully changed." >&3
  run grafana_install "Password3456"
  [ "$status" -eq 0 ]
  echo -e "# \e[32mGrafana re-installation successful." >&3
  run curl --retry 5 --retry-connrefused --user admin:Password3456 --header "Content-Type: application/json" --request PUT --data "{\"password\":\"Password234\"}" http://localhost:3000/api/admin/users/1/password
  [ "$status" -eq 0 ]
  echo -e "# \e[32mGrafana settings sucessfully changed." >&3
}
