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

# Usage: report_audit_status "Exists" | "Not Found"
function report_audit_status() {
  local status="$1"
  case "${status}" in
    Exists) echo -e " [${GREEN}Exists${NC}]" ;;
    "Not Found") echo -e " [${YELLOW}Not Found${NC}]" ;;
    *) echo -e " [${YELLOW}${status}${NC}]" ;;
  esac
}
export -f report_audit_status

# Usage: run_gcloud <log_file_name> <gcloud command ...>
function run_gcloud() {
  local log_file_name=$1
  shift
  local log_file="${LOG_DIR}/${log_file_name}"
  local log_dir=$(dirname "${log_file}") # Get the directory part
  mkdir -p "${log_dir}" # Create the directory if it doesn't exist

  if (( DEBUG != 0 )); then
    echo "  RUNNING: ${@}" >&2
  fi
  "${@}" > "${log_file}" 2>&1
  local exit_code=$?
  if [[ ${exit_code} -ne 0 ]]; then
    if grep -q -e "Reauthentication failed" -e "gcloud auth login" -e "gcloud config set account" "${log_file}"; then
      echo -e "\n  ${RED}GCLOUD AUTHENTICATION ERROR:${NC}"
      echo -e "  Please run ${YELLOW}gcloud auth login${NC} and ${YELLOW}gcloud auth application-default login${NC} to re-authenticate." >&2
      exit 1
    fi
    echo -e "${RED}ERROR: ${NC}Command failed with exit code ${exit_code}. Log: ${log_file}" >&2
    cat "${log_file}" >&2
    return ${exit_code}
  fi
  return 0
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
function init_state_db() {
    local db_file="${STATE_DB}"
    if [[ ! -f "${db_file}" ]]; then
        sqlite3 "${db_file}" "CREATE TABLE IF NOT EXISTS resource_state (key TEXT PRIMARY KEY, json_data TEXT);"
    fi
}
export -f init_state_db

function update_state() {
    local resource_key=$1
    local resource_value=$2 # JSON string or "null"
    local db_file="${STATE_DB}"

    init_state_db

    local sql
    if [[ "${resource_value}" == "null" ]]; then
        sql="DELETE FROM resource_state WHERE key = '${resource_key}';"
    else
        local escaped_value=$(echo "${resource_value}" | sed "s/'/''/g")
        sql="INSERT OR REPLACE INTO resource_state (key, json_data) VALUES ('${resource_key}', '${escaped_value}');"
    fi
    sqlite3 "${db_file}" "${sql}"
}
export -f update_state

function get_state() {
    local resource_key=$1
    local db_file="${STATE_DB}"
    init_state_db
    local result=$(sqlite3 "${db_file}" "SELECT json_data FROM resource_state WHERE key = '${resource_key}';")
    if [[ -z "${result}" ]]; then
        echo "null"
    else
        echo "${result}"
    fi
}
export -f get_state

function refresh_resource_state() {
    local resource_key=$1
    local source_file=$2  # e.g., lib/dataproc/cluster.sh or ""
    shift 2
    local check_command=("$@") # Remaining arguments form the command

    local json_output
    local func_name="${check_command[0]}"

    if [[ -n "${source_file}" ]]; then
        # Source in a subshell, export the function, then run the command
        if ! json_output=$(source "${GCLOUD_DIR}/${source_file}" && export -f "${func_name}" && "${check_command[@]}"); then
            echo "ERROR: Failed to execute check_command in refresh_resource_state for key ${resource_key} from ${source_file}" >&2
            json_output="null"
        fi
    else
        # Function should already be in the environment (e.g., _check_exists)
        if ! json_output=$("${check_command[@]}"); then
             echo "ERROR: Failed to execute check_command in refresh_resource_state for key ${resource_key}" >&2
             json_output="null"
        fi
    fi

    if [[ -z "${json_output}" || "${json_output}" == "[]" ]]; then
      json_output="null"
    fi

    update_state "${resource_key}" "${json_output}"
}
export -f refresh_resource_state

# --- Audit Check Functions ---
# These functions are now designed to be called by the audit script.
# They return a JSON object with details if a resource is found, or the string "null".
# Call this with command and arguments as separate words, not a single string.
function _check_exists() {
    echo "DEBUG _check_exists called with: $@" >&2
    local json_output
    # Execute the command, capturing stdout. Stderr is suppressed.
    json_output=$("$@" 2> /dev/null)
    local exit_code=$?
    echo "DEBUG INSIDE _check_exists:" >&2
    echo "DEBUG CMD: $@" >&2
    echo "DEBUG EXIT CODE: ${exit_code}" >&2
    echo "DEBUG JSON OUTPUT: ${json_output}" >&2

    if [[ ${exit_code} -eq 0 && -n "${json_output}" && "${json_output}" != "[]" ]]; then
        # If the command was successful and output is not empty or an empty JSON array, resource exists.
        echo "DEBUG _check_exists: Returning JSON" >&2
        echo "${json_output}"
    else
        # Otherwise, resource does not exist or an error occurred.
        echo "DEBUG _check_exists: Returning null" >&2
        echo "null"
    fi
}
export -f _check_exists
