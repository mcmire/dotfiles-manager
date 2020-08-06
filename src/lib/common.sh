PROJECT_DIR=$(dirname $(dirname $(absolute-path-of $0)))
SOURCE_DIR="$PROJECT_DIR/src"
COMMAND=
DOTFILES_HOME=${DOTFILES_HOME:-$HOME}

inspect-command() {
  echo "                 >" "$@"
}

build-destination-path() {
  echo "$DOTFILES_HOME/.$1"
}

format-source-path() {
  local source_path="${1/$PROJECT_DIR/\$DOTFILES}"

  if [[ -d $source_path ]]; then
    source_path="${source_path}/"
  fi

  echo "$source_path"
}

format-destination-path() {
  local destination_path="${1/$DOTFILES_HOME/~}"

  if [[ -d $destination_path ]]; then
    destination_path="${destination_path}/"
  fi

  echo "$destination_path"
}

format-announcement-prefix() {
  local color="$1"
  local action="$2"
  local action_width="$3"
  local subaction="$4"
  local subaction_width="$5"

  local colorized_action=$(colorize $color "$(printf "%${action_width}s" "$action")")
  local colorized_subaction=$(colorize yellow "$(printf "%${subaction_width}s" "$subaction")")
  echo "${colorized_action} ${colorized_subaction}"
}

announce() {
  local subaction="$1"
  local action="$2"
  shift 2

  local source_path=
  local destination_path=
  local formatted_source_path=
  local formatted_destination_path=

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
    local formatted_source_path=$(format-source-path "$source_path")
  fi

  if [[ $destination_path ]]; then
    local formatted_destination_path=$(format-destination-path "$destination_path")
  fi

  set +e
  local color=
  color="$(${COMMAND}__determine-action-color "$action")"
  if [[ $? -eq 1 ]]; then
    error "Couldn't find color for action '$action'!"
    echo "Please check the definition of ${COMMAND}__determine-action-color()."
    exit 1
  fi
  set -e

  local prefix="$(
    format-announcement-prefix \
      "$color" \
      "$action" \
      $(${COMMAND}__action-width) \
      "$subaction" \
      $(${COMMAND}__subaction-width)
  )"
  eval '${COMMAND}__announce' \
    '"$subaction"' \
    '"$prefix"' \
    ${formatted_source_path:+'-s "$formatted_source_path"'} \
    ${formatted_destination_path:+'-d "$formatted_destination_path"'}
}
