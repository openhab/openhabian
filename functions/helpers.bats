#!/usr/bin/env bats

load helpers.bash

testNonExistingHost() {
  tryUntil "ping -c 1 $1" 10 1
}

testAppearingHost() {
  ( sleep 3; echo "127.0.0.1  $1" >> /etc/hosts ) &

  tryUntil "ping -c 1 $1" 10 1
}

@test "inactive-tryExistingSite" {
  run testAppearingHost thiswillappear
  [ "$status" -eq 7 ]

  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Ping to host appearing after 3 seconds succeeded.${COL_DEF}" >&3
}

@test "inactive-tryNonExistingSite" {
  run testNonExistingHost nothisdoesnotexit
  [ "$status" -eq 0 ]

  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Pinging to nonexistingsite failed (correctly so).${COL_DEF}" >&3
}

@test "unit-cond_echo" {
  run cond_echo 'Generic Text @!/\1'
  [ "$status" -eq 0 ]
  [[ $output == *'Generic Text @!/\1'* ]]

  SILENT=1
  run cond_echo 'Generic Text @!/\2'
  [ "$status" -eq 0 ]
  [[ $output == '' ]]
}
