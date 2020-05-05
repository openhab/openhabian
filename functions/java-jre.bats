#!/usr/bin/env bats

load java-jre
load helpers

@test "installation-java_exist" {
  run java -version
  [ "$status" -eq 0 ]
  [[ $output == *"Zulu"* ]]
}

@test "unit-zulu_fetch_tar_url" {
  run fetch_zulu_tar_url 32-bit
  echo "# Fetched .tar.gz download link for Java Zulu 32-bit: $output"
  curl -s --head "$output" | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null # Check if link is valid, result it $?
  [ $? -eq 0 ]
}

@test "destructive-update_java-64bit_tar" {
  echo -e "# \e[36mZulu 64-bit Java installation is being (test-)installed..." >&3
  case "$(uname -m)" in
    aarch64|arm64|x86_64|amd64) ;;
    *) skip ;;
  esac
  run systemctl start openhab2
  run java_zulu_8_tar 64-bit
  echo -e "# \e[32mZulu 64-bit Java installation successful." >&3
  [ "$status" -eq 0 ]
  echo -e "# \e[32mZulu 64-bit Java installation successful." >&3
  run systemctl is-active --quiet openhab2
  [ "$status" -eq 0 ]
  run java -version
  [ "$status" -eq 0 ]
  [[ $output == *"Zulu"* ]]
  [[ $output == *"64"* ]]
}

@test "destructive-update_java-32bit_tar" {
  echo -e "# \e[36mZulu 32-bit Java installation is being (test-)installed..." >&3
  run systemctl start openhab2
  run java_zulu_8_tar 32-bit
  echo -e "# \e[32mZulu 32-bit Java installation successful." >&3
  [ "$status" -eq 0 ]
  echo -e "# \e[32mZulu 32-bit Java installation successful." >&3
  run systemctl is-active --quiet openhab2
  [ "$status" -eq 0 ]
  run java -version
  [ "$status" -eq 0 ]
  [[ $output == *"Zulu"* ]]
  [[ $output == *"32"* ]]
}

@test "destructive-install_adopt" {
  echo -e "# \e[36mAdoptOpenJDK Java installation is being (test-)installed..." >&3
  run systemctl start openhab2
  run adoptopenjdk_install_apt
  echo -e "# \e[32mAdoptOpenJDK Java installation successful." >&3
  [ "$status" -eq 0 ]
  echo -e "# \e[32mAdoptOpenJDK Java installation successful." >&3
  run systemctl is-active --quiet openhab2
  [ "$status" -eq 0 ]
  run java -version
  [ "$status" -eq 0 ]
  [[ $output == *"AdoptOpenJDK"* ]]
}
