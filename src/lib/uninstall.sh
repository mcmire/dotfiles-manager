uninstall__print-help() {
  cat <<TEXT
$(colorize blue "## DESCRIPTION")

The 'uninstall' command will remove symlinks in your home folder based on the
contents of the src/ directory. It will iterate over the files there and do one
of a few things depending on what it encounters:

* If it encounters a file, it will remove the corresponding symlink from your
  home directory if it points to this file.
  EXAMPLE: src/tmux.conf removes a symlink at ~/.tmux.conf if the symlink points
  to this file.
* If it encounters a directory, it will recurse the directory and remove
  symlinks inside of your home directory according to the previous rule (with
  the directory renamed so as to begin with a dot).
  EXAMPLE: src/rbenv is iterated over to find src/rbenv/default-gems.
  src/rbenv/default-gems removes a symlink at ~/.rbenv/default-gems if the
  symlink points to this file.

There are some exceptions to this:

* If it encounters a file anywhere that ends in ._no-link, it will remove the
  corresponding file from your home directory if it has the same content.
  EXAMPLE: src/gitconfig._no-link removes a file at ~/.gitconfig if both files
  are the same.
* If it encounters a directory anywhere that has a .no-recurse file, it will
  NOT recurse the directory; it will remove the symlink for the directory if it
  points to the source directory.
  EXAMPLE: src/zsh, because it contains a .no-recurse file, removes a symlink at
  ~/.zsh.

No files that do not point to or match a corresponding file in src/ will be
removed unless you specify --force.

Finally, if you want to know what this command will do before running it for
real, and especially if this is the first time you're running it, use the
--dry-run option. For further output, use the --verbose option.

$(colorize blue "## USAGE")

$(colorize bold "$0 $COMMAND [OPTIONS]")

where OPTIONS are:

--dry-run, --noop, -n
  Don't actually change the filesystem.
--force, -f
  Usually symlinks that do not point to files in src/ and files that end in
  ._no-link that do not match the file they were copied from are not removed.
  This bypasses that.
--verbose, -V
  Show every command that is run when it is run.
--help, -h
  You're looking at it ;)
TEXT
}

uninstall__parse-args() {
  DRY_RUN=0
  FORCE=0
  VERBOSE=0

  local arg=

  if [[ $# -eq 0 ]]; then
    error "No arguments given."
    echo "Please run $0 $COMMAND --help for usage."
    exit 1
  fi

  while [[ ${1:-} ]]; do
    arg="${1:-}"
    case "$arg" in
      --dry-run | --noop | -n)
        DRY_RUN=1
        shift
        ;;
      --force | -f)
        FORCE=1
        shift
        ;;
      --verbose | -V)
        VERBOSE=1
        shift
        ;;
      --help | -h | -?)
        ${COMMAND}__print-help | more -R
        exit
        ;;
      *)
        error "Unknown argument '$arg' given."
        echo "Please run $0 $COMMAND --help for usage."
        exit 1
    esac
  done
}

uninstall__determine-action-color() {
  local action="$1"

  case $action in
    delete | purge | overwrite)
      echo "red"
      ;;
    absent | different | unlinked | unrecognized | unknown)
      echo "blue"
      ;;
    *)
      exit 1
      ;;
  esac
}

uninstall__action-width() {
  echo 12
}

uninstall__subaction-width() {
  echo 8
}

uninstall__announce() {
  local subaction="$1"
  local prefix="$2"
  shift 2

  local source_path=
  local destination_path=

  while [[ ${1:-} ]]; do
    case "$1" in
      -s)
        source_path="$2"
        shift 2
        ;;
      -d)
        destination_path="$2"
        shift 2
        ;;
      *)
        error "Invalid argument '$1', must be -s SOURCE or -d DESTINATION."
        exit 1
        ;;
    esac
  done

  if [[ $source_path ]]; then
    echo "${prefix} ${destination_path} <-- ${source_path}"
  else
    echo "${prefix} ${destination_path}"
  fi
}

uninstall__remove-file() {
  local full_destination_path="$1"

  if [[ $VERBOSE -eq 1 ]]; then
    inspect-command rm "$full_destination_path"
  fi

  if [[ $DRY_RUN -eq 0 ]]; then
    rm "$full_destination_path"
  fi
}

uninstall__process-non-link() {
  local full_source_path="$1"
  local non_template_full_source_path="${full_source_path%._no-link}"
  local destination_path="${non_template_full_source_path#$PROJECT_DIR/src/}"
  local full_destination_path=$(build-destination-path "$destination_path")

  if [[ -f $full_destination_path ]]; then
    if files-equal "$full_source_path" "$full_destination_path" || [[ $FORCE -eq 1 ]]; then
      announce non-link delete -s "$full_source_path" -d "$full_destination_path"
      uninstall__remove-file "$full_destination_path"
    else
      announce non-link different -s "$full_source_path" -d "$full_destination_path"
    fi
  else
    announce non-link absent -s "$full_source_path" -d "$full_destination_path"
  fi
}

uninstall__process-entry() {
  local full_source_path="$1"
  local destination_path="${full_source_path#$PROJECT_DIR/src/}"
  local full_destination_path=$(build-destination-path "$destination_path")

  if [[ -h $full_destination_path ]]; then
    announce link delete -s "$full_source_path" -d "$full_destination_path"
    uninstall__remove-file "$full_destination_path"
  elif [[ -e $full_destination_path ]]; then
    if [[ $FORCE -eq 1 ]]; then
      announce entry purge -s "$full_source_path"
      uninstall__remove-file "$full_destination_path"
    else
      announce entry unlinked -d "$full_destination_path"
    fi
  fi
}

uninstall__print-result() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo
    info "Don't worry — no files were removed!"
  else
    echo
    success "All files have been removed, you're good!"
    echo "(Not the output you expect? Run --force to force-remove skipped files.)"
  fi
}
