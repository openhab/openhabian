#!/usr/bin/env bats

load packages
load helpers


teardown_file() {
  echo -e "# \e[36mHomegear test cleanup..." >&3
  systemctl stop homegear.service || true
  # TODO: fix homegear shutdown handling, is does not properly shut down and will cause bats tests to hang
  #ps aux|grep -i homeg >&3
  # workaround in place:
  killall -9 homegear || true
}

@test "destructive-homegear_install" {
  echo -e "# \e[36mHomegear installation starting..." >&3
  run homegear_setup
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mHomegear installation successful." >&3
  # TODO: fix homegear service, currently it does not detect running instance in CI
  #run systemctl status homegear.service
  #echo "$output" >&3
  #run systemctl is-active --quiet homegear.service
  #if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  # workaround in place: (pgrep would be better, but in doubt that it is installed in CI)
  run bash -c "ps aux | grep homegear | grep -v grep"
  [ "$status" -eq 0 ]
  echo -e "# \e[32mHomegear service running." >&3
}
