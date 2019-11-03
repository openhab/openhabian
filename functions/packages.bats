#!/usr/bin/env bats

load packages
load helpers

@test "destructive-homegear_install" {
  echo -e "# \e[32mHomegear installation starting..." >&3
  run homegear_setup
  [ "$status" -eq 0 ]
  echo -e "# \e[32mHomegear installation successful." >&3
  run systemctl is-active --quiet homegear.service
  [ "$status" -eq 0 ]
  echo -e "# \e[32mHomegear service running." >&3
}
