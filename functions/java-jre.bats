#!/usr/bin/env bats

load java-jre.bash
load helpers.bash

@test "java-install_zulu8-64bit" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Zulu 8 64-bit Java installation is being (test-)installed...${COL_DEF}" >&3
  case "$(uname -m)" in
    aarch64|arm64|x86_64|amd64) ;;
    *) skip ;;
  esac
  run java_zulu_prerequisite "Zulu8-64" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  run java_zulu_fetch "Zulu8-64" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  run java_zulu_install "Zulu8-64" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Zulu 8 64-bit Java installation successful.${COL_DEF}" >&3
}

@test "java-install_zulu11-64bit" {
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

@test "java-install_zulu8-32bit" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Zulu 8 32-bit Java installation is being (test-)installed...${COL_DEF}" >&3
  run java_zulu_prerequisite "Zulu8-32" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  run java_zulu_fetch "Zulu8-32" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  run java_zulu_install "Zulu8-32" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Zulu 8 32-bit Java installation successful.${COL_DEF}" >&3
}

@test "java-install_zulu11-32bit" {
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

@test "java-install_adopt" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] AdoptOpenJDK 11 Java installation is being (test-)installed...${COL_DEF}" >&3
  run adoptopenjdk_install_apt 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] AdoptOpenJDK 11 Java installation successful.${COL_DEF}" >&3
}
