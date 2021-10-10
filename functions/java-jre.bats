#!/usr/bin/env bats

load java-jre.bash
load helpers.bash

@test "installation-java_install_zulu11-64bit" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Zulu 11 64-bit Java installation is being (test-)installed...${COL_DEF}" >&3
  case "$(uname -m)" in
    aarch64|arm64|x86_64|amd64) ;;
    *) skip ;;
  esac
  run java_zulu_prerequisite "Zulu11-64" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  run java_zulu_fetch "Zulu11-64" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  run java_zulu_install "Zulu11-64" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Zulu 11 64-bit Java installation successful.${COL_DEF}" >&3
}

@test "installation-java_install_zulu11-32bit" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Zulu 11 32-bit Java installation is being (test-)installed...${COL_DEF}" >&3
  run java_zulu_prerequisite "Zulu11-32" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  run java_zulu_fetch "Zulu11-32" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  run java_zulu_install "Zulu11-32" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Zulu 11 32-bit Java installation successful.${COL_DEF}" >&3
}

@test "installation-java_install_zulu17-64bit" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Zulu 17 64-bit Java installation is being (test-)installed...${COL_DEF}" >&3
  case "$(uname -m)" in
    aarch64|arm64|x86_64|amd64) ;;
    *) skip ;;
  esac
  run java_zulu_prerequisite "Zulu17-64" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  run java_zulu_fetch "Zulu17-64" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  run java_zulu_install "Zulu17-64" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Zulu 17 64-bit Java installation successful.${COL_DEF}" >&3
}

@test "installation-java_install_zulu17-32bit" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Zulu 17 32-bit Java installation is being (test-)installed...${COL_DEF}" >&3
  run java_zulu_prerequisite "Zulu17-32" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  run java_zulu_fetch "Zulu17-32" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  run java_zulu_install "Zulu17-32" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Zulu 17 32-bit Java installation successful.${COL_DEF}" >&3
}

@test "installation-java_install_adopt11" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] AdoptOpenJDK 11 Java installation is being (test-)installed...${COL_DEF}" >&3
  run adoptopenjdk_install_apt "11" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] AdoptOpenJDK 11 Java installation successful.${COL_DEF}" >&3
}

@test "installation-java_install_adopt17" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] AdoptOpenJDK 17 Java installation is being (test-)installed...${COL_DEF}" >&3
  run adoptopenjdk_install_apt "17" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] AdoptOpenJDK 17 Java installation successful.${COL_DEF}" >&3
}
