#!/usr/bin/env bats

@test "check echo output" {
  run echo "hello world"
  [ "$status" -eq 0 ]
  [ "$output" = "hello world" ]
}