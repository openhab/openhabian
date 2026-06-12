#!/usr/bin/env bats

load zram.bash
load helpers.bash
load system.bash

teardown_file() {
  systemctl kill zram-config.service || true
}

check_zram_mounts() {
  local FILE=/etc/ztab

  while read -r line; do
    case "$line" in
      "#"*)
        # Skip comment line
        continue
        ;;

      "")
        # Skip empty line
        continue
        ;;

      *)
        set -- $line
        TYPE=$1
        TARGET=$5
        if [ "$TYPE" == "swap" ]; then
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
        ;;
    esac
  done < "$FILE"
}

check_zram_removal() {
  local FILE=/etc/ztab

  while read -r line; do
    case "$line" in
      "#"*)
        # Skip comment line
        continue
        ;;

      "")
        # Skip empty line
        continue
        ;;

      *)
        set -- $line
        TYPE=$1
        TARGET=$5
        if [ "$TYPE" == "swap" ]; then
          if ! [ "$(swapon | grep -q zram)" ]; then
            echo "# $(basename $0) error: swap still on zram." >&3
            return 1
          fi
        else
          if [ "$(df $5 | awk '/overlay/ { print $1 }' | tr -d '0-9')" == "overlay" ]; then
            echo "# $(basename $0) error: ${TARGET} still on overlay." >&3
            return 1
          fi
        fi
        ;;
    esac
  done < "$FILE"
}

@test "unit-zram_dependency" {
  local createdZtab="no"
  local dropinDir="/etc/systemd/system/zram-config.service.d"
  local oldDropinDir="/etc/systemd/system/zram.service.d"
  local backupDir

  backupDir="$(mktemp -d /tmp/zram-dependency-test.XXXXX)"
  if ! [[ -f /etc/ztab ]]; then createdZtab="yes"; touch /etc/ztab; fi
  if [[ -f "${dropinDir}/override.conf" ]]; then cp "${dropinDir}/override.conf" "${backupDir}/override.conf"; fi
  rm -rf "$dropinDir" "$oldDropinDir"

  run zram_dependency install foobar 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  grep -qs "^Before=openhab.service foobar.service$" "${dropinDir}/override.conf"
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Adding zram service dependency verified.${COL_DEF}" >&3

  run zram_dependency remove foobar 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  ! grep -qs "foobar.service" "${dropinDir}/override.conf"
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Removing zram service dependency verified.${COL_DEF}" >&3

  # migrate dependencies from old zram.service.d drop-in directory, which
  # systemd never applied to zram-config.service
  rm -rf "$dropinDir"
  mkdir -p "$oldDropinDir"
  printf '[Unit]\nBefore=openhab.service smbd.service\n' > "${oldDropinDir}/override.conf"
  run zram_dependency install 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  [ ! -d "$oldDropinDir" ]
  grep -qs "^Before=openhab.service smbd.service$" "${dropinDir}/override.conf"
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Migration of zram service dependencies verified.${COL_DEF}" >&3

  rm -rf "$dropinDir"
  if [[ -f "${backupDir}/override.conf" ]]; then
    mkdir -p "$dropinDir"
    cp "${backupDir}/override.conf" "${dropinDir}/override.conf"
  fi
  if [[ $createdZtab == "yes" ]]; then rm -f /etc/ztab; fi
  rm -rf "$backupDir"
}

@test "inactive-srv-mounts" {
  if running_in_docker; then skip "Not executing srv mount test because Docker does not support mount units."; fi
  if ! openhab_is_installed; then skip "Not executing srv mount test because openHAB is not installed."; fi

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] srv mount test starting...${COL_DEF}" >&3
  run srv_bind_mounts 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  for srvDir in sys conf userdata addons; do
    run mountpoint -q "/srv/openhab-${srvDir}"
    if [ "$status" -ne 0 ]; then echo "# $(basename "$0") error: /srv/openhab-${srvDir} is not mounted." >&3; fi
    [ "$status" -eq 0 ]
  done
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Availability of /srv bind mounts verified.${COL_DEF}" >&3

  # the zram overlay mounts must propagate into the /srv bind mounts so that
  # Samba shares show live data instead of the stale lower directory (#2060)
  if grep -qs "/var/lib/openhab/persistence" /etc/ztab && [ "$(systemctl is-active zram-config.service)" = "active" ]; then
    [ "$(stat -f -c %T /srv/openhab-userdata/persistence)" = "overlayfs" ]
    echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Propagation of zram overlay into /srv bind mounts verified.${COL_DEF}" >&3
  fi
}

@test "inactive-zram" {
  if ! is_arm; then skip "Not executing zram test because not on native ARM architecture hardware."; fi

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Zram test installation starting...${COL_DEF}" >&3
  run init_zram_mounts "install" 3>&-
  echo "$output" >&3
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
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
