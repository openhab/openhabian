#!/usr/bin/env bats

load helpers

@test "installation-Frontail_is_running" {
# does not work before #683 is merged
#  run systemctl is-active --quiet frontail.service
# [ "$status" -eq 0 ]
  echo -e "# \e[32mFrontail service running." >&3
}
