#!/bin/bash

debug() {
  if [ -n "$DEBUG_PARSEARGS" ]; then
    echo "$*"
  fi
}

cleanup() {
  unset _short_arg \
    _long_arg \
    _var_optional \
    _var_repeat \
    _var_name \
    _shift_args
}

parse-variable() {
  local var="$1"
  if [ -n "$_var_repeat" ]; then
    echo "Repeating argument must be the last positional argument"
    return 1
  fi
  if [[ "$var" =~ ^\[.*\]$ ]]; then
    _var_optional=1
    # Strip off the []
    local var="${var#[}"
    local var="${var%]}"
  elif [ -n "$_var_optional" ]; then
    echo "Cannot have required positional arguments after optional ones"
    return 1
  fi
  if [[ "$var" =~ \.\.\.$ ]]; then
    _var_repeat=1
    local var="${var%...}"
  fi
  if [[ "$var" =~ ^\<.*\>$ ]]; then
    # Strip off the <>
    local var="${var#<}"
    local var="${var%>}"
    # Uppercase
    _var_name="${var^^}"
  else
    echo "Unrecognized variable format '$var'"
    return 1
  fi
}

parse-usage() {
  local line="$1"
  local args="$(echo "$line" | sed -e 's/^ *[^ ]* *//')"
  for arg in $args; do
    parse-variable "$arg"
    positional_args=("${positional_args[@]}" "$_var_name")
    pos_arg_optional[$_var_name]=$_var_optional
    pos_arg_repeat[$_var_name]=$_var_repeat
  done
}

parse-short-opt() {
  local arg="$(echo "$1" | cut -f 2 -d -)"
  if [ ${#arg} -gt 1 ]; then
    local char="$(echo "$arg" | cut -f 1 -d ' ')"
    local var="$(echo "$arg" | cut -f 2 -d ' ')"
  else
    local char="$arg"
    local var=1
  fi
  short_args[$char]="$var"
  _short_arg="$char"
}

parse-long-opt() {
  # Trim whitespace, leading '--', and replace remaining '-' with '_'
  local arg=$(echo $1 | sed 's/^[ \-]*//' | tr - _)
  local key="$(echo "$arg" | cut -f 1 -d =)"
  if [ "$arg" == "$key" ]; then
    local var=1
  else
    local var="$(echo "$arg" | cut -f 2 -d =)"
  fi
  long_args[$key]="${var-1}"
  _long_arg="$key"
}

parse-option() {
  local line="$1"
  local opts="$(echo "$line" | sed -e 's/  .*$//')"
  if [[ "$opts" =~ ,\ *--[a-z] ]]; then
    local short="$(echo "$opts" | cut -f 1 -d ,)"
    local long="$(echo "$opts" | cut -f 2 -d ,)"
    parse-short-opt "$short"
    parse-long-opt "$long"
    short_to_long[$_short_arg]="$_long_arg"
  elif [[ "$opts" =~ ^\ *-- ]]; then
    parse-long-opt "$opts"
  else
    parse-short-opt "$opts"
  fi
}

setvar() {
  local varname=${1^^}
  if [ -n "${!varname}" ]; then
    echo "ENV variable '${varname}' already set!"
    return 1
  fi
  eval "$varname=\"${2-1}\""
}

unsetvar() {
  local varname=${1^^}
  eval "unset $varname"
}

parsedocs() {
  if [ -n "$USAGE" ]; then
    local usage="$USAGE"
    _shift_args=
  else
    local usage="${1?First argument must be the usage string}"
    _shift_args=1
  fi

  local state="usage"
  declare -g -A short_args=()
  declare -g -A long_args=()
  declare -g -A short_to_long=()
  declare -g -a positional_args=()
  declare -g -A pos_arg_optional=()
  declare -g -A pos_arg_repeat=()
  while read -r line; do
    if [ "${line,,}" == "options:" ]; then
      local state="options"
      continue
    elif [[ "$line" =~ ^\ *$ ]]; then
      local state=
      continue
    fi
    case $state in
      usage)
        parse-usage "$line"
        local state=
        ;;
      options)
        parse-option "$line"
        ;;
    esac
  done <<< "$usage"
  debug "Short args: ${!short_args[@]}"
  debug "Long args: ${!long_args[@]}"
  debug "Positional args: ${positional_args[@]}"
}

parseargs() {
  cleanup
  parsedocs "$@"
  if [ $_shift_args ]; then
    shift
  fi
  _resetargs
  _parseargs "$@"
  local code=$?
  cleanup
  return $code
}

parseargsnoreset() {
  cleanup
  parsedocs "$@"
  if [ $_shift_args ]; then
    shift
  fi
  _parseargs "$@"
  local code=$?
  cleanup
  return $code
}

_parseargs() {
  local opts="h-:"
  for key in "${!short_args[@]}"; do
    if [ "${short_args[$key]}" == "1" ]; then
      local opts="${key}${opts}"
    else
      local opts="${key}:${opts}"
    fi
  done
  debug "Opts: $opts"
  debug "Parsing arguments: $*"
  unset OPTIND
  while getopts "$opts" opt; do
    case $opt in
      -)
        case $OPTARG in
          help)
            echo "$usage"
            return 1
            ;;
          *)
            local key="$(echo "$OPTARG" | cut -f 1 -d = | tr - _)"
            local val="$(echo "$OPTARG" | cut -f 2 -d =)"
            local varname="${long_args[$key]}"
            if [ -z "$varname" ]; then
              echo "Unrecognized argument --$key"
              echo "$usage"
              return 1
            elif [ "$varname" == 1 ]; then
              setvar $key
            else
              setvar $varname $val
            fi
            ;;
        esac
        ;;
      h)
        echo "$usage"
        return 1
        ;;
      \?)
        echo "$usage"
        return 1
        ;;
      *)
        local varname="${short_args[$opt]}"
        if [ "$varname" == "1" ]; then
          if [ -n "${short_to_long[$opt]}" ]; then
            opt="${short_to_long[$opt]}"
          fi
          setvar $opt
        else
          setvar $varname $OPTARG
        fi
        ;;
    esac
  done
  shift $(($OPTIND-1))

  # Parse positional arguments
  for arg in ${positional_args[@]}; do
    local val="$1"
    local optional="${pos_arg_optional[$arg]}"
    local repeat="${pos_arg_repeat[$arg]}"
    if [ -n "$val" ]; then
      if [ -n "$repeat" ]; then
        setvar $arg "$*"
      else
        setvar $arg $val
        shift
      fi
    elif [ -z "$optional" ]; then
      echo "Missing positional argument '$arg'"
      echo "$usage"
      return 1
    fi
  done
}

_resetargs() {
  for key in ${!long_args[@]}; do
    local val=${long_args[$key]}
    if [ "$val" == "1" ]; then
      unsetvar "$key"
    else
      unsetvar "$val"
    fi
  done
  for key in ${!short_args[@]}; do
    if [ -z "${short_to_long[$key]}" ]; then
    local val=${short_args[$key]}
      if [ "$val" == "1" ]; then
        unsetvar "$key"
      else
        unsetvar "$val"
      fi
    fi
  done
  for key in ${positional_args[@]}; do
    unsetvar "$key"
  done
}

resetargs() {
  cleanup
  parsedocs "$@"
  _resetargs
  cleanup
}
