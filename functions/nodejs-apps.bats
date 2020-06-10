#!/usr/bin/env bats

load nodejs-apps
load helpers

setup_file() {
  export BASEDIR="${BATS_TEST_DIRNAME}/.."
}

teardown_file() {
  unset BASEDIR
  systemctl stop frontail.service || true
}

@test "installation-frontail_install" {
  echo -e "# \e[36mFrontail installation starting...\e[0m" >&3
  run frontail_setup
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mFrontail installation successful.\e[0m" >&3
  run systemctl is-active --quiet frontail.service
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# \e[32mFrontail service is running.\e[0m" >&3
}
