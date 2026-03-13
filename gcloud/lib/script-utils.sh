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

# --- State Management Functions ---
function get_state() {
    if [[ ! -f "${STATE_FILE}" ]]; then
        echo "{}"
        return
    fi
    cat "${STATE_FILE}"
}

function update_state() {
    local resource_key=$1
    local resource_value=$2 # This should be a JSON string or "null"
    
    local current_state=$(get_state)
    local new_state=$(jq --arg key "${resource_key}" --argjson value "${resource_value}" '.[$key] = $value' <<< "${current_state}")
    echo "${new_state}" > "${STATE_FILE}"
}

# --- Audit Check Functions ---
# These functions are now designed to be called by the audit script.
# They return a JSON object with details if a resource is found, or the string "null".
function _check_exists() {
  local command_to_run="$1"
  local json_output
  
  # The command_to_run should be a gcloud command with --format=json
  # that returns a JSON object if the resource exists and fails otherwise.
  json_output=$(eval "${command_to_run}" 2>/dev/null)
  
  if [[ -n "${json_output}" ]]; then
    echo "${json_output}"
  else
    echo "null"
  fi
}
export -f _check_exists
