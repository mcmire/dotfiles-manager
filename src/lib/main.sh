read-config-file() {
  if [[ -f $CONFIG_FILE_PATH ]]; then
    config::read $CONFIG_FILE_PATH --install INSTALL_CONFIG
  fi
}

write-config-file() {
  config::write $CONFIG_FILE_PATH --install INSTALL_CONFIG
}

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
  local rest

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
      shift
      ;;
    *)
      error "Unknown command '$arg'."
      echo "Please run $0 --help for usage."
      exit 1
      ;;
  esac

  rest=()
  while [[ ${1:-} ]]; do
    arg="${1:-}"
    case "$arg" in
      --dry-run | --noop | -n)
        COMMON_CONFIG[dry_run]=1
        shift
        ;;
      --force | -f)
        COMMON_CONFIG[force]=1
        shift
        ;;
      --verbose | -V)
        COMMON_CONFIG[verbose]=1
        shift
        ;;
      --help | -h | -?)
        ${COMMAND}__print-help | more -R
        exit
        ;;
      *)
        rest+=("$arg")
        shift
        ;;
    esac
  done

  ${COMMAND}__parse-args "${rest[@]}"
}

process-entry() {
  local source_path="$1"
  local dir="$2"
  local full_source_path=$(absolute-path-of "$dir/$source_path")

  if [[ -d $full_source_path && ! -e "$full_source_path/.no-recurse" ]]; then
    recurse-dir "$full_source_path"
  elif [[ $full_source_path =~ \.__no-link__$ ]]; then
    ${COMMAND}__process-non-link "$full_source_path"
  else
    ${COMMAND}__process-entry "$full_source_path"
  fi
}

recurse-dir() {
  local dir="$1"
  local source_path=

  # Process /__overrides__.cfg
  if [[ $dir == "$SOURCE_DIR" && -f "$dir/__overrides__.cfg" ]]; then
    process-entry "__overrides__.cfg" "$dir"
  fi

  # Process files
  find "$dir"/* -maxdepth 0 -type f -not \( -name __install__.sh -or -name __overrides__.cfg \) -exec basename {} \; | {
    while IFS= read -r source_path; do
      process-entry "$source_path" "$dir"
    done
  }

  # Process __install__.sh
  if [[ -f "$dir/__install__.sh" && -x "$dir/__install__.sh" ]]; then
    process-entry "__install__.sh" "$dir"
  fi

  # Process subdirectories
  find "$dir"/* -maxdepth 0 -type d -exec basename {} \; | {
    while IFS= read -r source_path; do
      process-entry "$source_path" "$dir"
    done
  }
}

main() {
  read-config-file
  parse-args "$@"

  if [[ ${COMMON_CONFIG[dry_run]} -eq 0 ]]; then
    write-config-file
  fi

  case $COMMAND in
    install | uninstall)
      if [[ ${COMMON_CONFIG[dry_run]} -eq 1 ]]; then
        info "Running in dry-run mode."
        echo
      fi
      recurse-dir "$SOURCE_DIR"
      ${COMMAND}__print-result
      ;;
    *)
      error "Unknown command $COMMAND."
      exit 1
      ;;
  esac
}
