absolute-path-of() {
  echo $(cd "$(dirname "$1")" &>/dev/null && pwd)/$(basename "$1")
}

PROJECT_DIR=$(dirname $(dirname $(absolute-path-of $0)))
SOURCE_DIR="$PROJECT_DIR/src"
COMMAND=
DOTFILES_HOME=${DOTFILES_HOME:-$HOME}
CONFIG_FILE_PATH="$DOTFILES_HOME/.dotfilesrc"
declare -A COMMON_CONFIG
COMMON_CONFIG=([dry_run]=0 [force]=0 [verbose]=0)
declare -A INSTALL_CONFIG
