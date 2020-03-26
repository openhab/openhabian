#!/usr/bin/env bats

load java-jre
load helpers

@test "unit-zulu_fetch_tar_url" {
  echo -e "# \e[32mTesting zulu java installation..." >&3-
  run echo "https://cdn.azul.com/zulu-embedded/bin/zulu8.40.0.178-ca-jdk1.8.0_222-linux_aarch32hf.tar.gz"
  echo "# Fetched .TAR download link for \"arm-32-bit-hf\": $output"
  curl -s --head "$output" | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null # Check if link is valid, result it $?
  [ $? -eq 0 ]
}

@test "installation-java_exist" {
  run java -version
  [ "$status" -eq 0 ]
  [[ $output == *"Zulu"* ]]
}

@test "destructive-update_java-64bit_tar" {
  echo -e "# \e[32mTesting java installation..." >&3-
  case "$(uname -m)" in
    aarch64|arm64|x86_64|amd64) ;;
    *) skip ;;
  esac
  run systemctl start openhab2
  run java_zulu_8_tar 64-bit
  [ "$status" -eq 0 ]
  run systemctl is-active --quiet openhab2
  [ "$status" -eq 0 ]
  run java -version
  [ "$status" -eq 0 ]
  [[ $output == *"Zulu"* ]]
  [[ $output == *"64"* ]]
  echo -e "# \e[32mDone java installation..." >&3-
}

@test "destructive-update_java-32bit_tar" {
  echo -e "# \e[32mTesting zulu java update..." >&3-  
  run systemctl start openhab2
  run java_zulu_8_tar 32-bit
  [ "$status" -eq 0 ]
  run systemctl is-active --quiet openhab2
  [ "$status" -eq 0 ]
  run java -version
  [ "$status" -eq 0 ]
  [[ $output == *"Zulu"* ]]
  [[ $output == *"32"* ]]
  echo -e "# \e[32mDone zulu java update..." >&3-
}