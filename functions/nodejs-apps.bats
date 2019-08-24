#!/usr/bin/env bats

load helpers

@test "installation-Frontail_is_running" {
  run systemctl is-active --quiet frontail.service
  [ "$status" -eq 0 ]
}