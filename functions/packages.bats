#!/usr/bin/env bats

load packages
load helpers

@test "destructive-homegear_install" {
  echo -e "# \e[32mTesting Homegear installation..." >&3-  
  run homegear_setup
  [ "$status" -eq 0 ]
  run systemctl is-active --quiet homegear.service
  [ "$status" -eq 0 ]
  echo -e "# \e[32mTesting Homegear installation done." >&3-  
}
