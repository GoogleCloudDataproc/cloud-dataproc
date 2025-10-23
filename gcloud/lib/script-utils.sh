#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage: print_status "Message..."
function print_status() {
  local message="$1"
  local first_word=$(echo "${message}" | awk '{print $1}')
  local rest_of_message=$(echo "${message}" | cut -d' ' -f2-)
  echo -en "${YELLOW}${first_word}${NC} ${rest_of_message}"
}
export -f print_status

# Usage: report_result "Status"
function report_result() {
  local status="$1"
  case "${status}" in
    Pass) echo -e " [${GREEN}Pass${NC}]" ;;    Exists) echo -e " [${GREEN}Exists${NC}]" ;;    Created) echo -e " [${GREEN}Created${NC}]" ;;    Updated) echo -e " [${GREEN}Updated${NC}]" ;;    Deleted) echo -e " [${GREEN}Deleted${NC}]" ;;    "Not Found") echo -e " [${YELLOW}Pass*${NC}]" ;;    Fail) echo -e " [${RED}Fail${NC}]" ;;    Skipped) echo -e " [${BLUE}Skipped${NC}]" ;;    Kept) echo -e " [${BLUE}Kept${NC}]" ;;    Info) echo -e " [${BLUE}Info${NC}]" ;;    *) echo -e " [${YELLOW}${status}${NC}]" ;;  esac
}
export -f report_result

# Usage: run_gcloud <log_file_name> <gcloud command ...>
function run_gcloud() {
  local log_file_name=$1
  shift
  local log_file="${REPRO_TMPDIR}/${log_file_name}"
  local log_dir=$(dirname "${log_file}") # Get the directory part
  mkdir -p "${log_dir}" # Create the directory if it doesn't exist

  if (( DEBUG != 0 )); then
    echo "  RUNNING: $*" >&2
  fi
  "$@" > "${log_file}" 2>&1
  local exit_code=$?
  if [[ ${exit_code} -ne 0 ]]; then
    if grep -q -e "Reauthentication failed" -e "gcloud auth login" -e "gcloud config set account" "${log_file}"; then
      echo -e "\n  ${RED}GCLOUD AUTHENTICATION ERROR:${NC}"
      echo -e "  Please run ${YELLOW}gcloud auth login${NC} and ${YELLOW}gcloud auth application-default login${NC} to re-authenticate." >&2
    elif (( DEBUG != 0 )); then
      cat "${log_file}" >&2
    else
      :
    fi
  fi
  return ${exit_code}
}
export -f run_gcloud

# Usage: parse_args "$@"
function parse_args() {
  CREATE_CLUSTER=true # Default for create scripts
  FORCE_DELETE=false # Default for destroy scripts
  GCLOUD_QUIET=false # Default
  FORCE_AUDIT=false # Default for audit scripts

  PARAMS=""
  while (( "$#" )); do
    case "$1" in
      --no-create-cluster)
        CREATE_CLUSTER=false
        shift
        ;;      --force)
        FORCE_DELETE=true
        FORCE_AUDIT=true # Audit scripts use this too
        shift
        ;;      --quiet-gcloud)
        GCLOUD_QUIET=true
        shift
        ;;      *)
        PARAMS="$PARAMS \"$1\""
        shift
        ;;    esac
  done
  eval set -- "${PARAMS}"
}
export -f parse_args

# --- Sentinel Functions ---
function get_sentinel_file() {
  local phase_name="$1"
  local sentinel_name="$2"
  echo "${SENTINEL_DIR}/${phase_name}-${sentinel_name}"
}
export -f get_sentinel_file

function create_sentinel() {
  local phase_name="$1"
  local sentinel_name="$2"
  touch "$(get_sentinel_file "${phase_name}" "${sentinel_name}")"
}
export -f create_sentinel

function check_sentinel() {
  local phase_name="$1"
  local sentinel_name="$2"
  [[ -f "$(get_sentinel_file "${phase_name}" "${sentinel_name}")" ]]
}
export -f check_sentinel

function remove_sentinel() {
  local phase_name="$1"
  local sentinel_name="$2"
  rm -f "$(get_sentinel_file "${phase_name}" "${sentinel_name}")"
}
export -f remove_sentinel

function clear_sentinels() {
  local phase_name="$1"
  rm -f "${SENTINEL_DIR}/${phase_name}-*"
}
export -f clear_sentinels

# --- Audit Check Functions ---
function check_resource() {
  local test_name="$1"
  local command_to_run="$2"
  local grep_pattern="$3"
  local optional="${4:-false}"
  local log_file="${LOG_DIR}/$(echo "$test_name" | tr ' /:' '___').log"

  print_status "Checking: ${test_name}... "

  eval "${command_to_run}" > "${log_file}" 2>&1

  if grep -q "${grep_pattern}" "${log_file}"; then
    if [[ "${optional}" == "true" && "${FORCE_AUDIT}" == "false" ]]; then
      report_result "Kept"
      return 0
    else
      report_result "Fail"
      return 1
    fi
  else
    report_result "Not Found"
    return 0
  fi
}
export -f check_resource

function check_resource_exact() {
  local test_name="$1"
  local command_to_run="$2"
  local optional="${3:-false}"
  local log_file="${LOG_DIR}/$(echo "$test_name" | tr ' /:' '___').log"

  print_status "Checking: ${test_name}... "
  if eval "${command_to_run}" > "${log_file}" 2>&1; then
    # Command succeeded, check if it produced output
    if [[ $(wc -l < "${log_file}") -gt 0 ]]; then
      # Output found
      if [[ "${optional}" == "true" && "${FORCE_AUDIT}" == "false" ]]; then
        report_result "Kept"
        return 0
      else
        report_result "Fail"
        return 1
      fi
    else
      # Command succeeded but no output, so Not Found
      report_result "Not Found"
      return 0
    fi
  else
    # Command failed, resource likely does not exist
    report_result "Not Found"
    return 0
  fi
}
export -f check_resource_exact
