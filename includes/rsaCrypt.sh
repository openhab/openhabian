#!/bin/bash

SEPARATOR="___"
COMMENT="###"
BEGIN="%%"
OPTS="-aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -salt"
VERSION=2.1.0

encrypt() {

  file=$2;
  PUBLIC_KEY="$1"

  # Creating temporary files for encryption
  TMP_OUT="$(mktemp "${TMPDIR:-/tmp}/$(basename "$0").XXXXXX.out")"
  TMP_KEY="$(mktemp "${TMPDIR:-/tmp}/$(basename "$0").XXXXXX.key")"
  trap 'shred "$TMP_OUT" "$TMP_KEY"; rm -rf "$TMP_OUT" "$TMP_KEY" ' EXIT SIGINT


  # Generating random secret for file encryption
  openssl rand -base64 64 > "$TMP_KEY";

  # Copy this script first
  cat $0 > "$TMP_OUT"
  echo $BEGIN$BEGIN >> "$TMP_OUT"

  echo -e "Encrypted with version $VERSION using the following key : \n$(cat $PUBLIC_KEY) " >> "$TMP_OUT"
  echo $COMMENT >> "$TMP_OUT"

  # Crypt the secret key with public key
  openssl rsautl -encrypt -pubin -inkey <(ssh-keygen -f "$PUBLIC_KEY" -e -m PKCS8) -ssl -in "$TMP_KEY" | openssl base64 >> "$TMP_OUT";
  # Add a separator between parts of the file
  echo "$SEPARATOR" >> "$TMP_OUT";

  # Crypt the original file with the secret key
  openssl enc $OPTS -in $file -pass file:"$TMP_KEY" | openssl base64 >> "$TMP_OUT"

  outfile="${file}.enc.sh"
  cat "$TMP_OUT" > $outfile

}


decrypt () {

  file=${0%.sh}
  key=$1
  lines=$(wc -l < $0)

  # Creating temporary files for encryption
  TMP_OUT="$(mktemp "${TMPDIR:-/tmp}/$(basename "$0").XXXXXX.out")"
  TMP_KEY="$(mktemp "${TMPDIR:-/tmp}/$(basename "$0").XXXXXX.key")"
  trap 'shred "$TMP_OUT" "$TMP_KEY" && rm -rf "$TMP_OUT" "$TMP_KEY" ' EXIT SIGINT

  # Extract the content to a separate file
  grep -A $lines "$BEGIN$BEGIN" $0 | grep -v "$BEGIN" > "$file"

  #Get the comment part
  grep -B $lines "$COMMENT" $file | grep -v "$COMMENT"

  # Get the key part
  grep -B $lines "$SEPARATOR" $file | grep -v "$SEPARATOR" | grep -A $lines "$COMMENT" | grep -v "$COMMENT" | openssl base64 -d > "$TMP_OUT"

  # Try to decrypt the key
  openssl rsautl -decrypt -inkey "$key" -in "$TMP_OUT" -out "$TMP_KEY" 2> /dev/null

  if  [[ $? -ne 0 ]] ; then

    # If decryption failed, it might be because of wrong key format
    echo "Decryption failed , reencoding key" >&2

    # Change openssh key to RSA
    cp $key "$TMP_KEY"
    ssh-keygen -f "$TMP_KEY" -p -N "" -m pem

    # Decrypt the key again with the PEM key
    openssl rsautl -decrypt -inkey "$TMP_KEY" -in "$TMP_OUT" -out "$TMP_KEY"

  fi

  # Get the crypted file part
  grep -A $lines "$SEPARATOR" $file | grep -v "$SEPARATOR" | openssl base64 -d > "$TMP_OUT"
  outfile=${file%.enc}

  # Decrypting the file contents
  openssl enc -d -aes-256-cbc $OPTS -in "$TMP_OUT" -pass file:"$TMP_KEY" > $outfile


  if  [[ $? -ne 0 ]] ; then

    echo "===================================="
    echo " Error in decrypting $outfile , wrong key ?"
    echo "===================================="
    rm $outfile

  else

    # Display success message
    echo "===================================="
    echo " $outfile successfully decrypted"
    echo "===================================="

  fi


  # Remove the .enc file
  rm $file


}

retrieve_keys() {

  rm $HOME/.ssh/${1}.*.pub

  (curl -sf "https://gitlab.com/${1}.keys" | grep 'ssh-rsa' | while read key ; do i=$((1+i)); echo $key > "$HOME/.ssh/${1}.${i}.pub" ; done; )

  if [[ "$(grep ^ssh $HOME/.ssh/${1}.*.pub | wc -l)" -lt 1 ]]; then
    echo "Could not find any SSH key for $1" >&2
    exit 1
  fi
}

usage() {
cat <<HERE
  USAGE:
    Encryption : produces file.enc.sh
    $0 -e <-i public_key_file | -g gitlab handle> <file>
    Decryption : produces file
    bash <file.enc.sh>
HERE
exit;
}


mode="decrypt"
KEY=""
user=""

while getopts "ei:g:" option; do
  case "${option}" in
    i)
      if [[ -r "${OPTARG}" ]] ; then
        echo "Using key file ${OPTARG}" >& 2
        KEY=${OPTARG}
      else
        echo "Unable to open key file ${OPTARG}"
        usage
      fi
      ;;
    g)
      retrieve_keys ${OPTARG}
      KEY=""
      user=${OPTARG}
      ;;
    e)
      mode="crypt"
      ;;
  esac
done
shift $((OPTIND-1))


if [[ "$mode" = "crypt"  ]]; then

  if [[ "$#" -lt 1 ]] ; then
    echo "Wrong number of arguments"
    usage ;
  fi ;

  file=$1;


  if [[ -r "$KEY" ]]; then
    encrypt "$KEY" "$file"
  else
    ls -1 $HOME/.ssh/${user}.*.pub | while read key
    do
      i=$((1+i))
      cp $1 ${1}.${i}
      encrypt "${key}" ${1}.${i}
      rm ${1}.${i}
    done
  fi;



elif [[ "$mode" = "decrypt" ]]; then
  if ! [[ -r "$KEY" ]]; then
    KEY="$HOME/.ssh/id_rsa"
    echo "Loading default private key file $KEY, try with the -i <path_to_privkey> switch ?" >& 2
  fi;
  decrypt "$KEY"
else
  echo "Wrong mode $mode"
  usage
fi;

exit;
