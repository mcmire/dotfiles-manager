print-help() {
  cat <<TEXT
$(colorize bold "## DESCRIPTION")

This script will either create symlinks in your home directory based on the
contents of src/ or delete previously installed symlinks.

$(colorize bold "## USAGE")

The main way to call this script is by saying one of:

    $0 install
    $0 uninstall

If you want to know what either of these commands do, say:

    $0 install --help
    $0 uninstall --help
TEXT
}

parse-args() {
  if [[ $# -eq 0 ]]; then
    error "Missing command."
    echo "Please run $0 --help for usage."
    exit 1
  fi

  case "$1" in
    --help)
      print-help
      exit
      ;;
    install | uninstall)
      COMMAND="$1"
      ${COMMAND}__parse-args "${@:2}"
      ;;
    *)
      error "Unknown command '$arg'."
      echo "Please run $0 --help for usage."
      exit 1
      ;;
  esac
}

process-entry() {
  local source_path="$1"
  local dir="$2"
  local full_source_path=$(absolute-path-of "$dir/$source_path")

  if [[ -d $full_source_path && ! -e "$full_source_path/.no-recurse" ]]; then
    recurse-dir "$full_source_path"
  elif [[ $full_source_path =~ \._no-link$ ]]; then
    ${COMMAND}__process-non-link "$full_source_path"
  else
    ${COMMAND}__process-entry "$full_source_path"
  fi
}

recurse-dir() {
  local dir="$1"
  local source_path=

  find "$dir"/* -maxdepth 0 -type f -not \( -name _install.sh \) -exec basename {} \; | {
    while IFS= read -r source_path; do
      process-entry "$source_path" "$dir"
    done
  }

  if [[ -f "$dir/_install.sh" && -x "$dir/_install.sh" ]]; then
    process-entry "_install.sh" "$dir"
  fi

  find "$dir"/* -maxdepth 0 -type d -exec basename {} \; | {
    while IFS= read -r source_path; do
      process-entry "$source_path" "$dir"
    done
  }
}

main() {
  parse-args "$@"

  case $COMMAND in
    install | uninstall)
      if [[ $DRY_RUN -eq 1 ]]; then
        info "Running in dry-run mode."
        echo
      fi
      recurse-dir "$PROJECT_DIR/src"
      ${COMMAND}__print-result
      ;;
    *)
      error "Unknown command $COMMAND."
      exit 1
      ;;
  esac
}
