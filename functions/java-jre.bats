#!/usr/bin/env bats

load java-jre
load helpers

@test "installation-java_exist" {
  run java -version
  [ "$status" -eq 0 ]
  [[ $output == *"Zulu"* ]]
}

@test "destructive-update_java" {
  run systemctl start openhab2
  run java_zulu
  [ "$status" -eq 0 ]
  run systemctl is-active --quiet openhab2
  [ "$status" -eq 0 ]
}