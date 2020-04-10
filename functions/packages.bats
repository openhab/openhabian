#!/usr/bin/env bats

load packages
load helpers

@test "destructive-homegear_install" {
  echo -e "# \e[36mHomegear installation starting..." >&3
  run homegear_setup
  [ "$status" -eq 0 ]
  echo -e "# \e[32mHomegear installation successful." >&3
# does not work before #683 is merged
#  run systemctl is-active --quiet homegear.service
#  [ "$status" -eq 0 ]
  echo -e "# \e[32mHomegear service running." >&3
}
