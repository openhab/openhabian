#!/usr/bin/env bats 

load helpers

@test "dev-query-arch" {
  if is_arm; then
    echo -e "# \e[32mRunning on ARM." >&3
  else
    echo -ne "# \e[32mRunning on " >&3
    /usr/bin/arch >&3
  fi
}

@test "dev-query-virt" {
  VIRT=$(virt-what)
  echo -e "# \e[32mRunning on ${VIRT:-native HW}." >&3
}
