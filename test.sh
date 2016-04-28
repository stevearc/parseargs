#!/bin/bash
set -o pipefail
set -o errtrace
RED='\033[0;31m'
BLACK='\033[0;30m'
DARK_GRAY='\033[1;30m'
RED='\033[0;31m'
LIGHT_RED='\033[1;31m'
GREEN='\033[0;32m'
LIGHT_GREEN='\033[1;32m'
BROWN='\033[0;33m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
LIGHT_BLUE='\033[1;34m'
PURPLE='\033[0;35m'
LIGHT_PURPLE='\033[1;35m'
CYAN='\033[0;36m'
LIGHT_CYAN='\033[1;36m'
LIGHT_GRAY='\033[0;37m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
. ./parseargs.sh

usage1="$0

Options:
  -l                      Short flag
  -m MODE                 Short arg
  --version               Long flag
  --bounce=BOUNCE         Long arg
  -s, --save              Short & long flag
  -f FOO, --foo=FOO       Short & long arg
  --no-frobnicate         Long flag with dash
  --drop-tables=TABLES    Long arg with dash
"

usage2="$0 <arg> [<optional_arg>] [<repeating_arg>...]"

test-short-flag() {
  parseargs "$usage1"
  [ -z "$L" ]
  parseargs "$usage1" -l
  [ -n "$L" ]
}

test-short-arg() {
  parseargs "$usage1"
  [ -z "$MODE" ]
  parseargs "$usage1" -m asdf
  [ "$MODE" == "asdf" ]
}

test-long-flag() {
  parseargs "$usage1"
  [ -z "$VERSION" ]
  parseargs "$usage1" --version
  [ -n "$VERSION" ]
}

test-long-dash-flag() {
  parseargs "$usage1"
  [ -z "$NO_FROBNICATE" ]
  parseargs "$usage1" --no-frobnicate
  [ -n "$NO_FROBNICATE" ]
}

test-long-arg() {
  parseargs "$usage1"
  [ -z "$BOUNCE" ]
  parseargs "$usage1" --bounce=asdf
  [ "$BOUNCE" == "asdf" ]
}

test-long-dashed-arg() {
  parseargs "$usage1"
  [ -z "$TABLES" ]
  parseargs "$usage1" --drop-tables=foo,bar
  [ -n "$TABLES" ]
}

test-short-long-flag() {
  parseargs "$usage1"
  [ -z "$SAVE" ]
  parseargs "$usage1" -s
  [ -n "$SAVE" ]
  parseargs "$usage1" --save
  [ -n "$SAVE" ]
}

test-short-long-arg() {
  parseargs "$usage1"
  [ -z "$FOO" ]
  parseargs "$usage1" -f asdf
  [ "$FOO" == "asdf" ]
  parseargs "$usage1" --foo=jkl
  [ "$FOO" == "jkl" ]
}

test-required() {
  parseargs "$usage2" || local pass=1
  [ -n "$pass" ]
  parseargs "$usage2" asdf
  [ "$ARG" == "asdf" ]
}

test-optional() {
  parseargs "$usage2" a
  [ -z "$OPTIONAL_ARG" ]
  parseargs "$usage2" a foo
  [ "$OPTIONAL_ARG" == "foo" ]
}

test-repeat() {
  parseargs "$usage2" a
  [ -z "$REPEATING_ARG" ]
  parseargs "$usage2" a foo
  [ -z "$REPEATING_ARG" ]
  parseargs "$usage2" a foo bar
  [ "$REPEATING_ARG" == "bar" ]
  parseargs "$usage2" a foo bar baz
  [ "$REPEATING_ARG" == "bar baz" ]
}

test-reset-opts() {
  MODE=1
  VERSION=1
  BOUNCE=1
  SAVE=1
  L=1
  FOO=1
  resetargs "$usage1"
  [ -z "$MODE" ]
  [ -z "$VERSION" ]
  [ -z "$BOUNCE" ]
  [ -z "$SAVE" ]
  [ -z "$L" ]
  [ -z "$FOO" ]
}

test-reset-args() {
  ARG=1
  OPTIONAL_ARG=1
  REPEATING_ARG=1
  resetargs "$usage2"
  [ -z "$ARG" ]
  [ -z "$OPTIONAL_ARG" ]
  [ -z "$REPEATING_ARG" ]
}

test-parse-reset() {
  MODE=1
  parseargs "$usage1"
  [ -z "$MODE" ]
}

test-parse-no-reset() {
  MODE=1
  parseargsnoreset "$usage1" -l
  [ "$MODE" == "1" ]
  [ -n "$L" ]
}

print-error() {
  local sourcefile="$1"
  local lineno="$2"
  echo "Failure in $sourcefile:$lineno"
  sed -n "${lineno}p" "$sourcefile"
  _error=1
}
trap 'print-error "$BASH_SOURCE" "$LINENO"' ERR

teardown() {
  unset _error
}

main() {
  if [ -n "$1" ]; then
    local tests="$@"
  else
    local tests="$(declare -F | cut -f 3 -d ' ' | grep ^test)"
  fi
  local pass=0
  local fail=0
  for current_test in $tests; do
    $current_test
    if [ $_error ]; then
      echo -e "${RED}fail${NC} - $current_test"
      ((fail++)) || true
    else
      echo -e "${GREEN}ok${NC} - $current_test"
      ((pass++)) || true
    fi
    teardown
  done
  echo
  if [ $pass -gt 0 ]; then
    echo -e "${GREEN}${pass} passing${NC}"
  fi
  if [ $fail -gt 0 ]; then
    echo -e "${RED}${fail} failing${NC}"
  fi
}

main "$@"
