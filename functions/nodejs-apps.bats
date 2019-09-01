#!/usr/bin/env bats

load helpers

@test "installation-Frontail_is_running" {
  VIRT=$(virt-what)
  if ! is_arm || [ "${VIRT}" != "native HW" ]; then skip "Not executing test for frontail service because not on native ARM architecture hardware."; fi

  run systemctl is-active --quiet frontail.service
  [ "$status" -eq 0 ]
}
