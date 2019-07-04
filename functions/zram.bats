#!/usr/bin/env bats 

load helpers
load zram

check_zram_mounts() {
  local FILE=/etc/ztab
  local i=0

  if ! [ -f ${FILE} ]; then
    echo "# zram not installed, can not test." >&3
    return 0
  fi
  while read -r line; do
    case "${line}" in
      "#"*) continue ;;
      "")   continue ;;
      *)    set -- ${line}
            TYPE=$1
	    TARGET=$5
	    echo "$(swapon | grep -q zram)"; echo $?
            if [ "${TYPE}" == "swap" ]; then
	      if [ $(swapon | grep -q zram) ]; then
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

  echo -e "# \e[32mzram installation successful." >&3
  return 0
}


@test "destructive-zram" {
  run init_zram_mounts install
  if ! [ -f /etc/ztab ]; then
    skip "zram not installed, can not test"
  fi

  run check_zram_mounts
  echo -e "# \e[32mAvailability of zram mounts verified." >&3

  [ "$status" -eq 0 ]
}

