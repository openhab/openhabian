#!/usr/bin/env bats

load java-jre
load helpers

@test "installation-java_exist" {
  run java -version
  [ "$status" -eq 0 ]
  [[ $output == *"Zulu"* ]]
}