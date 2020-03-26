#!/usr/bin/env bats

load helpers

@test "installation-Frontail_is_running" {
  echo -e "# \e[32mTesting Frontail installation..." >&3-  
  run systemctl is-active --quiet frontail.service
  [ "$status" -eq 0 ]
  echo -e "# \e[32mTesting Frontail installation done." >&3-  
}