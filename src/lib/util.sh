colorize() {
  local code=

  case "$1" in
    bold)
      code=1
      ;;
    red)
      code=31
      ;;
    green)
      code=32
      ;;
    yellow)
      code=33
      ;;
    blue)
      code=34
      ;;
    *)
      echo "WARNING: $1 is an invalid color"
      code=0
      ;;
  esac

  echo -ne "\033[${code}m"
  echo -n "${@:2}"
  echo -ne "\033[0m"
}

echo-in() {
  echo $(colorize "$@")
}

success() {
  echo-in green "$@"
}

warning() {
  echo-in yellow "$@"
}

info() {
  echo-in bold "$@"
}

error() {
  echo-in red "$@"
}

digest-file() {
  if type md5 &>/dev/null; then
    echo $(md5 -q "$1")
  elif type md5sum &>/dev/null; then
    echo $(md5sum "$1")
  else
    error "Could not find md5 or md5sum, aborting."
    exit 1
  fi
}

files-equal() {
  [[ $(digest-file "$1") == $(digest-file "$2") ]]
}
