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

@test "systemdsetup-srv-mounts" {
  if ! is_systemd_booted; then skip "Not executing srv mount test because systemd is not the running init system."; fi

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] srv mount test starting...${COL_DEF}" >&3
  mkdir -p /etc/openhab /var/lib/openhab/persistence /usr/share/openhab/addons
  run srv_bind_mounts 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  for srvDir in sys conf userdata addons; do
    run mountpoint -q "/srv/openhab-${srvDir}"
    if [ "$status" -ne 0 ]; then echo "# $(basename "$0") error: /srv/openhab-${srvDir} is not mounted." >&3; fi
    [ "$status" -eq 0 ]
  done
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Availability of /srv bind mounts verified.${COL_DEF}" >&3
}

@test "systemdsetup-zram" {
  if ! is_systemd_booted; then skip "Not executing zram setup test because systemd is not the running init system."; fi
  if ! is_arm; then skip "Not executing zram setup test because not on native ARM architecture hardware."; fi
  if ! [[ -d /sys/class/zram-control ]] && ! modprobe zram &> /dev/null; then skip "Not executing zram setup test because the zram kernel module is not available."; fi

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] zram setup test starting...${COL_DEF}" >&3
  if ! zram_is_installed; then
    run init_zram_mounts "install" 3>&-
    if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
    [ "$status" -eq 0 ]
  fi
  if ! grep -qs "/var/lib/openhab/persistence" /etc/ztab; then
    # without openHAB installed the persistence entry was removed, restore it
    # to be able to test overlay propagation into the /srv bind mounts
    printf 'dir\tzstd\t\t150M\t\t350M\t\t/var/lib/openhab/persistence\t/persistence.bind\n' >> /etc/ztab
    run systemctl restart zram-config.service
    [ "$status" -eq 0 ]
  fi
  run check_zram_mounts
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Availability of zram mounts verified.${COL_DEF}" >&3

  # the zram overlay mounts must propagate into the /srv bind mounts so that
  # Samba shares show live data instead of the stale lower directory (#2060)
  [ "$(stat -f -c %T /srv/openhab-userdata/persistence)" = "overlayfs" ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Propagation of zram overlay into /srv bind mounts verified.${COL_DEF}" >&3
}

@test "systemdboot-zram-srv-mounts" {
  if ! is_systemd_booted; then skip "Not executing boot order test because systemd is not the running init system."; fi
  if ! [[ -f "/etc/systemd/system/srv-openhab\x2duserdata.mount" ]]; then skip "Not executing boot order test because the /srv mounts are not set up."; fi

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] boot order test starting...${COL_DEF}" >&3
  for srvDir in sys conf userdata addons; do
    run mountpoint -q "/srv/openhab-${srvDir}"
    if [ "$status" -ne 0 ]; then echo "# $(basename "$0") error: /srv/openhab-${srvDir} is not mounted after boot." >&3; fi
    [ "$status" -eq 0 ]
  done
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Availability of /srv bind mounts after boot verified.${COL_DEF}" >&3

  # ordering the /srv mounts before zram-config.service must not create an
  # ordering cycle that makes systemd drop zram-config.service from the boot
  # transaction (#2060), an enabled but inactive service after boot means its
  # start job was deleted to break a cycle
  run bash -c "journalctl -b | grep -i 'ordering cycle' | grep -E 'zram-config|srv-openhab'"
  if [ "$status" -eq 0 ]; then echo "$output" >&3; fi
  [ "$status" -ne 0 ]
  if [ "$(systemctl is-enabled zram-config.service 2> /dev/null)" = "enabled" ]; then
    [ "$(systemctl is-active zram-config.service)" = "active" ]
  fi
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] No ordering cycle on zram-config.service after boot verified.${COL_DEF}" >&3

  if grep -qs "/var/lib/openhab/persistence" /etc/ztab; then
    [ "$(stat -f -c %T /srv/openhab-userdata/persistence)" = "overlayfs" ]
    echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Propagation of zram overlay into /srv bind mounts after boot verified.${COL_DEF}" >&3
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
