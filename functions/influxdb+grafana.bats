#!/usr/bin/env bats

load influxdb+grafana
load helpers

@test "destructive-install_influxDB" {
  run influxdb_install "Password1234"
  [ "$status" -eq 0 ]
  run systemctl is-active --quiet influxdb.service
  [ "$status" -eq 0 ]
}

@test "destructive-install_grafana" {
  run grafana_install "Password1234"
  [ "$status" -eq 0 ]
  run systemctl is-active --quiet grafana-server.service
  [ "$status" -eq 0 ]
}