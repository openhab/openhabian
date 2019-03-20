#!/usr/bin/env bats

load helpers

@test "unit-cond_echo" {
  run cond_echo 'Generic Text @!/\1'
  [ "$status" -eq 0 ]
  [[ $output == *'Generic Text @!/\1'* ]]
  
  SILENT=1
  run cond_echo 'Generic Text @!/\2'
  [ "$status" -eq 0 ]
  [[ $output == '' ]]
}