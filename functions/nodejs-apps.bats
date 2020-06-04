#!/usr/bin/env bats

load nodejs-apps
load helpers

setup_file() {
  export BASEDIR="${BATS_TEST_DIRNAME}/.."
}

@test "installation-Frontail_is_running" {
run frontail_setup
if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
run frontail -V
if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
[ "$status" -eq 0 ]

echo -e "# \e[32mFrontail properly installed." >&3
}
