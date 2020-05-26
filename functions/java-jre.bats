#!/usr/bin/env bats

load java-jre
load helpers

=======
@test "destructive-install_zulu8-64bit" {
>>>>>>> a03e933... Add Options for AdoptOpenJDK and Java 11
  echo -e "# \e[36mZulu 8 64-bit Java installation is being (test-)installed..." >&3
  case "$(uname -m)" in
    aarch64|arm64|x86_64|amd64) ;;
    *) skip ;;
  esac
<<<<<<< HEAD
  run systemctl start openhab2
  run fetch_zulu Zulu8-64
  run java_zulu_install
  echo -e "# \e[32mZulu 8 64-bit Java installation successful." >&3
=======
  run java_zulu_fetch Zulu8-64
  [ "$status" -eq 0 ]
  run java_zulu_install
  [ "$status" -eq 0 ]
  echo -e "# \e[32mZulu 8 64-bit Java installation successful." >&3
}

@test "destructive-install_zulu11-64bit" {
>>>>>>> a03e933... Add Options for AdoptOpenJDK and Java 11
  echo -e "# \e[36mZulu 11 64-bit Java installation is being (test-)installed..." >&3
  case "$(uname -m)" in
    aarch64|arm64|x86_64|amd64) ;;
    *) skip ;;
  esac
  run systemctl start openhab2
  run fetch_zulu Zulu11-64
  run java_zulu_install
  echo -e "# \e[32mZulu 11 64-bit Java installation successful." >&3
  [ "$status" -eq 0 ]
  echo -e "# \e[32mZulu 11 64-bit Java installation successful." >&3
  run systemctl is-active --quiet openhab2
  [ "$status" -eq 0 ]
  run java_zulu_install
  [ "$status" -eq 0 ]
  echo -e "# \e[32mZulu 11 64-bit Java installation successful." >&3
}

@test "destructive-install_zulu8-32bit" {
  echo -e "# \e[36mZulu 8 32-bit Java installation is being (test-)installed..." >&3
  run systemctl start openhab2
  run fetch_zulu Zulu8-32
  run java_zulu_install
  echo -e "# \e[32mZulu 8 32-bit Java installation successful." >&3
  [ "$status" -eq 0 ]
  echo -e "# \e[32mZulu 8 32-bit Java installation successful." >&3
  run systemctl is-active --quiet openhab2
  [ "$status" -eq 0 ]
  run java_zulu_install
  [ "$status" -eq 0 ]
  echo -e "# \e[32mZulu 8 32-bit Java installation successful." >&3
}

@test "destructive-install_zulu11-32bit" {
  echo -e "# \e[36mZulu 11 32-bit Java installation is being (test-)installed..." >&3
  run systemctl start openhab2
  run fetch_zulu Zulu11-32
  run java_zulu_install
  echo -e "# \e[32mZulu 11 32-bit Java installation successful." >&3
  [ "$status" -eq 0 ]
  echo -e "# \e[32mZulu 11 32-bit Java installation successful." >&3
  run systemctl is-active --quiet openhab2
  [ "$status" -eq 0 ]
  run java_zulu_install
  [ "$status" -eq 0 ]
  echo -e "# \e[32mZulu 11 32-bit Java installation successful." >&3
}

@test "destructive-install_adopt" {
  echo -e "# \e[36mAdoptOpenJDK 11 Java installation is being (test-)installed..." >&3
  run adoptopenjdk_install_apt
  [ "$status" -eq 0 ]
  echo -e "# \e[32mAdoptOpenJDK 11 Java installation successful." >&3
}
