#!/usr/bin/env bats

load packages
load helpers

@test "destructive-homegear_install" {
  run homegear_setup
  [ "$status" -eq 0 ]

  VIRT=$(virt-what)
  if [ "${VIRT}" != "native HW" ]; then skip "Not checking for running homegear service because on (emulated ?) architecture"; fi

  run systemctl is-active --quiet homegear.service
  [ "$status" -eq 0 ]
}
