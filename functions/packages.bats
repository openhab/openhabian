#!/usr/bin/env bats

load packages
load helpers

@test "destructive-homegear_install" {
  VIRT=$(virt-what)
  if [ "${VIRT}" != "native HW" ]; then skip "Not setting up homegear service because on (emulated ?) architecture."; fi

  run homegear_setup
  [ "$status" -eq 0 ]

  run systemctl is-active --quiet homegear.service
  [ "$status" -eq 0 ]
}
