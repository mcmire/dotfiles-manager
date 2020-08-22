config::read() {
  # Inspiration: <https://forums.bunsenlabs.org/viewtopic.php?id=5570>

  local file="$1"
  shift

  local arg
  local -A config_variable_map

  while [[ ${1:-} ]]; do
    arg="${1:-}"
    case "$arg" in
      --*)
        config_variable_map[${arg#--}]="$2"
        shift 2
        ;;
      *)
        error "Unknown argument '$arg' given."
        exit 1
    esac
  done

  local -n current_config_array
  local section_regex="^\[([[:alpha:]_][[:alnum:]_]*)\]$"
  local entry_regex="^([^=]+)=(.+)$"
  local lines line key value

  while read -r line; do
    if [[ -n $line ]]; then
      if [[ $line =~ $section_regex ]]; then
        if [[ -n ${BASH_REMATCH[1]} ]]; then
          local -n current_config_array=${config_variable_map[${BASH_REMATCH[1]}]}
        else
          echo "section_regex match failed"
          exit 1
        fi
      elif [[ $line =~ $entry_regex ]]; then
        if [[ -n ${BASH_REMATCH[1]} && -n ${BASH_REMATCH[2]} ]]; then
          key=$(config::parse-key ${BASH_REMATCH[1]})
          value=$(config::parse-value ${BASH_REMATCH[2]})
          current_config_array["${key}"]="${value}"
        else
          echo "entry_regex match failed"
          exit 1
        fi
      else
        echo "Could not parse line: $line"
        exit 1
      fi
    fi
  done < "$file"

  declare -p COMMON_CONFIG
  declare -p INSTALL_CONFIG
}

config::write() {
  local file="$1"
  shift

  local arg
  local -A config_variable_map=()

  while [[ ${1:-} ]]; do
    arg="${1:-}"
    case "$arg" in
      --*)
        config_variable_map[${arg#--}]="$2"
        shift 2
        ;;
      *)
        error "Unknown argument '$arg' given."
        exit 1
    esac
  done

  rm -f $file

  local index=0
  for section_name in "${!config_variable_map[@]}"; do
    local -n config_array=${config_variable_map[$section_name]}
    if [[ $index -gt 0 ]]; then
      echo >> $file
    fi
    echo "[$section_name]" >> $file

    for key in "${!config_array[@]}"; do
      if [[ "${config_array[$key]}" =~ ^[[:digit:]]+$ ]]; then
        echo "$key = ${config_array[$key]}" >> $file
      else
        echo "$key = \"${config_array[$key]}\"" >> $file
      fi
    done

    index=$index+1
  done
}

config::parse-key() {
  echo "$1" | \
    sed -Ee 's/^[[:blank:]]+//' | \
    sed -Ee 's/[[:blank:]]+$//'
}

config::parse-value() {
  echo "$1" | \
    sed -Ee 's/^[[:blank:]]+//' | \
    sed -Ee 's/[[:blank:]]+$//' | \
    sed -Ee "s/\"(.+)\"/\\1/" | \
    sed -Ee "s/'(.+)'/\\1/" | \
    sed -Ee "s!~/!$HOME/!" | \
    sed -Ee "s!/~!/$HOME!"
}
