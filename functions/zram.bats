#!/usr/bin/env bats

load zram.bash
load helpers.bash

teardown_file() {
  systemctl kill zram-config.service || true
}

check_zram_mounts() {
  local FILE=/etc/ztab
  local i=0

  while read -r line; do
    case "${line}" in
      "#"*) continue ;;
      "")   continue ;;
      *)    set -- ${line}
            TYPE=$1
	    TARGET=$5
	    echo "$(swapon | grep -q zram)"; echo $?
            if [ "${TYPE}" == "swap" ]; then
	      if [ "$(swapon | grep -q zram)" ]; then
                echo "# $(basename $0) error: swap not on zram." >&3
                return 1
              fi
            else
              if [ "$(df $5 | awk '/overlay/ { print $1 }' | tr -d '0-9')" != "overlay" ]; then
                echo "# $(basename $0) error: overlay for ${TARGET} not found." >&3
                return 1
              fi
            fi
            let i=$i+1
            ;;
    esac
  done < "$FILE"

  return 0
}

check_zram_removal() {
  local FILE=/etc/ztab
  local i=0

  while read -r line; do
    case "${line}" in
      "#"*) continue ;;
      "")   continue ;;
      *)    set -- ${line}
            TYPE=$1
	    TARGET=$5
            if [ "${TYPE}" == "swap" ]; then
	      if ! [ "$(swapon | grep -q zram)" ]; then
                echo "# $(basename $0) error: swap still on zram." >&3
                return 1
              fi
            else
              if ! [ "$(df $5 | awk '/overlay/ { print $1 }' | tr -d '0-9')" != "overlay" ]; then
                echo "# $(basename $0) error: ${TARGET} still on overlay." >&3
                return 1
              fi
            fi
            let i=$i+1
            ;;
    esac
  done < "$FILE"

  cat /usr/local/share/zram-config/logs/zram-config.log >>/tmp/zram-config.log
  return 0
}

@test "installation-zram" {
  if ! is_arm; then skip "Not executing zram test because not on native ARM architecture hardware."; fi

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Zram test installation starting...${COL_DEF}" >&3
  run init_zram_mounts "install" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Initial installation of zram mounts succeeded.${COL_DEF}" >&3
  run check_zram_mounts
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Availability of zram mounts verified.${COL_DEF}" >&3
  run init_zram_mounts "update" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Update of zram mounts succeeded.${COL_DEF}" >&3
  run check_zram_mounts
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Availability of updated zram mounts verified.${COL_DEF}" >&3
  run init_zram_mounts "uninstall" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Uninstall of zram mounts succeeded.${COL_DEF}" >&3
  run check_zram_removal
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Uninstall of zram mounts verified - none remaining.${COL_DEF}" >&3
}
