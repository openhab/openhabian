#!/usr/bin/env bats

load helpers

testthis() {
  tryUntil "wget -S --spider -t 3 --waitretry=4 $1 2>&1 | grep -q 'HTTP/1.1 200 OK'" 5 2
  ret=$(($? - $2))
  if [ $ret -ne 0 ]; then echo "OK"; return 0; else echo "failed."; return 1; fi
}

@test "unit-tryExistingSite" {
  testthis "http://www.openhab.org/" 5
  [ "$status" -eq 0 ]
  echo -e "# \n\e[32mGetting www.openhab.org in tryUntil loop succeeded." >&3
}

@test "unit-tryNonExistingSite" {
  run testthis "http://nothisdoesnotexistforsure/" 0
  [ "$status" -eq 0 ]
  echo -e "Getting non-existant URL in tryUntil loop correctly timed out." >&3
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
