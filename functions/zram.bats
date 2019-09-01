#!/usr/bin/env bats 

load helpers
load zram

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
	      if ! [ $(swapon | grep -q zram) ]; then
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

@test "destructive-zram" {
  run init_zram_mounts install
  [ "$status" -eq 0 ]

  run check_zram_mounts
  [ "$status" -eq 0 ]

  echo -e "# \e[32mInstallation and availability of zram mounts verified." >&3
}

@test "dev-zram" {
  if ! is_arm; then skip "Not executing zram test because not on ARM architecture"; fi

  run init_zram_mounts install
#  systemctl start zram-config
  [ "$status" -eq 0 ]
  echo -e "# \n\e[32mInitial installation of zram mounts succeeded." >&3
  run check_zram_mounts
  [ "$status" -eq 0 ]
  echo -e "# \e[32mAvailability of zram mounts verified." >&3
  run init_zram_mounts uninstall
  [ "$status" -eq 0 ]
  echo -e "# \e[32mUninstall of zram mounts succeeded." >&3
  run check_zram_removal
  [ "$status" -eq 0 ]
  echo -e "# \e[32mUninstall of zram mounts verified - none remaining." >&3
  run init_zram_mounts install
  [ "$status" -eq 0 ]
  echo -e "# \e[32mSecond installation of zram mounts succeeded." >&3
  run check_zram_mounts
  [ "$status" -eq 0 ]
  echo -e "# \e[32mAvailability of 2nd zram mounts verified." >&3

  echo -e "# \e[32mInstallation and availability of zram mounts verified." >&3
}

