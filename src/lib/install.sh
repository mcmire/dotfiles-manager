install__parse-args() {
  local arg

  while [[ ${1:-} ]]; do
    arg="${1:-}"
    case "$arg" in
      --*)
        INSTALL_CONFIG["${arg#--}"]="$2"
        shift 2
        ;;
      *)
        error "Unknown argument '$arg' given."
        echo "Please run $0 install --help for usage."
        exit 1
    esac
  done
}

install__print-help() {
  cat <<TEXT
$(colorize blue "## DESCRIPTION")

The 'install' command will create symlinks in your home folder based on the
contents of the src/ directory. It will iterate over the files there and do one
of a few things depending on what it encounters:

* If it encounters a file, it will create a symlink in your home folder that
  points to this file (with the file renamed so as to begin with a dot).
  EXAMPLE: src/tmux.conf creates a symlink at ~/.tmux.conf.
* If it encounters a directory, it will recurse the directory and create
  symlinks inside of your home directory according to the previous rule (with
  the directory renamed so as to begin with a dot).
  EXAMPLE: src/rbenv is iterated over to find src/rbenv/default-gems.
  src/rbenv/default-gems then creates a symlink at ~/.rbenv/default-gems.

There are some exceptions to this:

* If it encounters a file anywhere called _install.sh, it will treat that file
  as an executable and run it. (It assumes you have chmod'd this file correctly
  and that this script has a shebang.)
* If it encounters a file anywhere that ends in .__no-link__, it will copy this
  file to your home directory instead of creating a symlink.
  EXAMPLE: src/gitconfig.__no-link__ creates a file (not a symlink) at
  ~/.gitconfig.
* If it encounters a directory anywhere that has a .no-recurse file, it will
  NOT recurse the directory; instead, it will create a symlink for the
  directory.
  EXAMPLE: src/zsh, because it contains a .no-recurse file, creates a symlink at
  ~/.zsh.

No files will be overwritten unless you specify --force.

Finally, if you want to know what this command will do before running it for
real, and especially if this is the first time you're running it, use the
--dry-run option. For further output, use the --verbose option.

$(colorize blue "## USAGE")

$(colorize bold "$0 $COMMAND [FIRST_TIME_OPTIONS] [OTHER_OPTIONS]")

where FIRST_TIME_OPTIONS are one or more of:

--git-name NAME
  The name that you'll use to author Git commits.
--git-email EMAIL
  The email that you'll use to author Git commits.

and OTHER_OPTIONS are one or more of:

--dry-run, --noop, -n
  Don't actually change the filesystem.
--force, -f
  Usually dotfiles that already exist are not overwritten. This bypasses that.
--verbose, -V
  Show every command that is run when it is run.
--help, -h
  You're looking at it ;)
TEXT
}

install__determine-action-color() {
  local action="$1"

  case $action in
    create | run | read)
      echo "green"
      ;;
    overwrite)
      echo "red"
      ;;
    exists | same | unknown)
      echo "blue"
      ;;
    *)
      exit 1
      ;;
  esac
}

install__action-width() {
  echo 8
}

install__subaction-width() {
  echo 8
}

install__announce() {
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
    if [[ $destination_path ]]; then
      echo "${prefix} ${source_path} --> ${destination_path}"
    else
      echo "${prefix} ${source_path}"
    fi
  else
    echo "${prefix} ${destination_path}"
  fi
}

install__read-config-file() {
  local -A symlinks
  config::read "$1" --symlinks symlinks

  for source_path in "${!symlinks[@]}"; do
    install__link-file-with-announcement \
      "$(absolute-path-of "$source_path" $SOURCE_DIR)" \
      "${symlinks[$source_path]}"
  done
}

install__run-install-script() {
  local full_path="$1"

  if [[ ${COMMON_CONFIG[verbose]} -eq 1 ]]; then
    eval inspect-command env ${GIT_NAME:+'GIT_NAME="$GIT_NAME"'} ${GIT_EMAIL:+'GIT_EMAIL="$GIT_EMAIL"'} '"$full_path"'
  fi

  if [[ ${COMMON_CONFIG[dry_run]} -eq 0 ]]; then
    set +e

    eval env ${GIT_NAME:+'GIT_NAME="$GIT_NAME"'} ${GIT_EMAIL:+'GIT_EMAIL="$GIT_EMAIL"'} '"$full_path"'
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
      echo
      error "$(format-source-path "$full_path") failed with exit code $exit_code."
      echo "Take a closer look at this file. Perhaps you're using set -e and some command is failing?"
      exit 1
    fi

    set -e
  fi
}

install__copy-file() {
  local full_source_path="$1"
  local full_destination_path="$2"

  if [[ ${COMMON_CONFIG[verbose]} -eq 1 ]]; then
    inspect-command mkdir -p $(dirname "$full_destination_path")

    if [[ ${COMMON_CONFIG[force]} -eq 1 ]]; then
      inspect-command rm -f "$full_destination_path"
    fi

    inspect-command cp "$full_source_path" "$full_destination_path"
  fi

  if [[ ${COMMON_CONFIG[dry_run]} -eq 0 ]]; then
    mkdir -p $(dirname "$full_destination_path")

    if [[ ${COMMON_CONFIG[force]} -eq 1 ]]; then
      rm -f "$full_destination_path"
    fi

    cp "$full_source_path" "$full_destination_path"
  fi
}

install__process-non-link() {
  local full_source_path="$1"
  local non_template_full_source_path="${full_source_path%.__no-link__}"
  local destination_path="${non_template_full_source_path#$SOURCE_DIR/}"
  local full_destination_path=$(build-destination-path "$destination_path")

  if [[ -e $full_destination_path ]]; then
    if [[ ${COMMON_CONFIG[force]} -eq 1 ]]; then
      announce non-link overwrite -s "$full_source_path" -d "$full_destination_path"
      install__copy-file "$full_source_path" "$full_destination_path"
    else
      announce entry exists -s "$full_source_path" -d "$full_destination_path"
    fi
  else
    announce non-link create -s "$full_source_path" -d "$full_destination_path"
    install__copy-file "$full_source_path" "$full_destination_path"
  fi
}

install__link-file() {
  local full_source_path="$1"
  local full_destination_path="$2"

  if [[ ${COMMON_CONFIG[verbose]} -eq 1 ]]; then
    inspect-command mkdir -p $(dirname "$full_destination_path")

    if [[ ${COMMON_CONFIG[force]} -eq 1 ]]; then
      inspect-command rm -rf "$full_destination_path"
    fi

    inspect-command ln -s "$full_source_path" "$full_destination_path"
  fi

  if [[ ${COMMON_CONFIG[dry_run]} -eq 0 ]]; then
    mkdir -p $(dirname "$full_destination_path")

    if [[ ${COMMON_CONFIG[force]} -eq 1 ]]; then
      rm -rf "$full_destination_path"
    fi

    ln -s "$full_source_path" "$full_destination_path"
  fi
}

install__process-entry() {
  local full_source_path="$1"
  local destination_path="${full_source_path#$SOURCE_DIR/}"
  local full_destination_path=$(build-destination-path "$destination_path")
  local basename=$(basename "$full_source_path")

  if [[ $basename == "__overrides__.cfg" ]]; then
    announce config read -s "$full_source_path"
    install__read-config-file "$full_source_path"
  elif [[ $basename == "__install__.sh" ]]; then
    announce command run -s "$full_source_path"
    install__run-install-script "$full_source_path"
  else
    install__link-file-with-announcement "$full_source_path" "$full_destination_path"
  fi
}

install__link-file-with-announcement() {
  local full_source_path="$1"
  local full_destination_path="$2"

  if [[ -e $full_destination_path ]]; then
    if [[ ${COMMON_CONFIG[force]} -eq 1 ]]; then
      announce link overwrite -s "$full_source_path" -d "$full_destination_path"
      install__link-file "$full_source_path" "$full_destination_path"
    else
      announce link exists -s "$full_source_path" -d "$full_destination_path"
    fi
  else
    announce link create -s "$full_source_path" -d "$full_destination_path"
    install__link-file "$full_source_path" "$full_destination_path"
  fi
}

install__print-result() {
  if [[ ${COMMON_CONFIG[dry_run]} -eq 1 ]]; then
    echo
    info "Don't worry — no files were created!"
  else
    echo
    success "All files are installed, you're good!"
    echo "(Not the output you expect? Run --force to force-update skipped files.)"
  fi
}
