# Find the absolute script location dir (e.g. BASEDIR=/opt/openhabian)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  BASEDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$BASEDIR/$SOURCE"
done
BASEDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPTNAME="$(basename $SOURCE)"

REPOSITORYURL="https://github.com/openhab/openhabian"
CONFIGFILE="/etc/openhabian.conf"

