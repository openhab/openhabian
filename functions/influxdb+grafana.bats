#!/usr/bin/env bats

load influxdb+grafana
load helpers

setup_file() {
  echo -e "# \e[36mInfluxDB/Grafana test preparation..." >&3
}

teardown_file() {
  echo -e "# \e[36mInfluxDB/Grafana test cleanup..." >&3
  systemctl stop influxdb.service || true
  systemctl stop grafana-server || true
}

@test "destructive-influxDB_install" {
  echo -e "# \e[36mInfluxDB installation starting..." >&3
  run influxdb_install "Password1234"
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mInfluxDB installation successful." >&3
  run systemctl is-active --quiet influxdb.service
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mInfluxDB service running." >&3
  run curl --retry 5 --retry-connrefused -s --insecure --user "admin:Password1234" "http://localhost:8086/query" >/dev/null
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mInfluxDB service is responding." >&3
}

@test "destructive-grafana_install" {
  echo -e "# \e[36mGrafana installation starting..." >&3
  run grafana_install "Password1234"
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mGrafana installation successful." >&3
  run systemctl is-active --quiet grafana-server.service
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mGrafana service running." >&3
  run curl --retry 5 --retry-connrefused --user admin:Password1234 --header "Content-Type: application/json" --request PUT --data "{\"password\":\"Password234\"}" http://localhost:3000/api/admin/users/1/password
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mGrafana settings sucessfully changed." >&3
  run grafana_install "Password3456"
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mGrafana re-installation successful." >&3
  run curl --retry 5 --retry-connrefused --user admin:Password3456 --header "Content-Type: application/json" --request PUT --data "{\"password\":\"Password234\"}" http://localhost:3000/api/admin/users/1/password
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mGrafana settings sucessfully changed." >&3
}
