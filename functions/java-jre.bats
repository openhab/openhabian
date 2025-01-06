#!/usr/bin/env bats

load java-jre.bash
load helpers.bash

@test "installation-java_install_openjdk17" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] OpenJDK 17 Java is being (test-)installed...${COL_DEF}" >&3
  run java_install "17" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] OpenJDK 17 Java installation successful.${COL_DEF}" >&3
}

@test "installation-java_install_openjdk21" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] OpenJDK 21 Java is being (test-)installed...${COL_DEF}" >&3
  run java_install "21" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] OpenJDK 21 Java installation successful.${COL_DEF}" >&3
}

@test "installation-java_install_temurin17" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Temurin 17 Java is being (test-)installed...${COL_DEF}" >&3
  run java_install "Temurin17" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Temurin 17 Java installation successful.${COL_DEF}" >&3
}

@test "installation-java_install_temurin21" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Temurin 21 Java is being (test-)installed...${COL_DEF}" >&3
  run java_install "Temurin21" 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Temurin 21 Java installation successful.${COL_DEF}" >&3
}
