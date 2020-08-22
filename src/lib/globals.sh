absolute-path-of() {
  local dir=

  if [[ $1 =~ ^/ ]]; then
    echo "$1"
  else
    if [[ -n "${2:-}" ]]; then
      dir="$2/$(dirname "$1")"
    else
      dir="$(dirname "$1")"
    fi

    if [[ -d $dir ]]; then
      echo $(cd "$dir" &>/dev/null && pwd)/$(basename "$1")
    else
      echo "Not a directory: $dir"
      exit 1
    fi
  fi
}

PROJECT_DIR=$(dirname $(dirname $(absolute-path-of $0)))
SOURCE_DIR="$PROJECT_DIR/src"
COMMAND=
DOTFILES_HOME=${DOTFILES_HOME:-$HOME}
CONFIG_FILE_PATH="$DOTFILES_HOME/.dotfilesrc"
declare -A COMMON_CONFIG
COMMON_CONFIG=([dry_run]=0 [force]=0 [verbose]=0)
declare -A INSTALL_CONFIG
