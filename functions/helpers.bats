#!/usr/bin/env bats

load helpers

testNonExistingHost() {
  tryUntil "ping -c 1 $1" 10 1
}

testAppearingHost() {
  ( sleep 3; echo "127.0.0.1  $1" >> /etc/hosts ) &
 
  tryUntil "ping -c 1 $1" 10 1
}

@test "unit-tryExistingSite" {
  runc --debug testAppearingHost thiswillappear
  [ "$status" -eq 7 ]

  echo -e "# \n\e[32mPing to host appearing after 3 seconds succeeded." >&3
}

@test "unit-tryNonExistingSite" {
  runc --debug testNonExistingHost nothisdoesnotexit
  [ "$status" -eq 0 ]

  echo -e "# \n\e[32mPinging to nonexistingsite failed (correctly so)." >&3
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
