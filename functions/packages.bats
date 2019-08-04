#!/usr/bin/env bats

load packages
load helpers

@test "destructive-homegear_install" {
  run homegear_setup
  [ "$status" -eq 0 ]
  run systemctl is-active --quiet homegear.service
  [ "$status" -eq 0 ]
}