#!/bin/bash
#
# Misc GCP helper functions

function configure_gcloud() {
  print_status "Checking gcloud config..."
  local changed=false
  local log_file="gcloud_config.log"

  local current_project=$(gcloud config get core/project 2>/dev/null)
  if [[ "${current_project}" != "${PROJECT_ID}" ]]; then
    run_gcloud "${log_file}" gcloud config set core/project ${PROJECT_ID}
    changed=true
  fi

  local current_region=$(gcloud config get compute/region 2>/dev/null)
  if [[ "${current_region}" != "${REGION}" ]]; then
    run_gcloud "${log_file}" gcloud config set compute/region ${REGION}
    changed=true
  fi

  local current_zone=$(gcloud config get compute/zone 2>/dev/null)
  if [[ "${current_zone}" != "${ZONE}" ]]; then
    run_gcloud "${log_file}" gcloud config set compute/zone ${ZONE}
    changed=true
  fi

  local current_dp_region=$(gcloud config get dataproc/region 2>/dev/null)
  if [[ "${current_dp_region}" != "${REGION}" ]]; then
    run_gcloud "${log_file}" gcloud config set dataproc/region ${REGION}
    changed=true
  fi

  if [[ "${changed}" = true ]]; then
    report_result "Updated"
  else
    report_result "Pass"
  fi
}
export -f configure_gcloud

function check_project() {
    print_status "Verifying project ${PROJECT_ID}..."
    local project_raw
    project_raw=$(get_state "project")
    if [[ "${project_raw}" == "null" || -z "${project_raw}" ]]; then
      print_status "Project not found in state DB" >&2
      report_result "Fail"
      exit 1
    fi
    local project_state=$(echo "${project_raw}" | jq -r '.lifecycleState // "NOT_FOUND"')

    if [[ "${project_state}" == "ACTIVE" ]]; then
        report_result "Pass"
    else
        report_result "Fail"
        echo "  - Project ${PROJECT_ID} is not ACTIVE (state: ${project_state})." >&2
        exit 1
    fi
}

function check_billing() {
    print_status "Verifying billing for ${PROJECT_ID}..."
    local billing_raw
    billing_raw=$(get_state "billing")
    if [[ "${billing_raw}" == "null" || -z "${billing_raw}" ]]; then
      print_status "Billing info not found in state DB" >&2
      report_result "Fail"
      exit 1
    fi
    local billing_enabled=$(echo "${billing_raw}" | jq -r '.billingEnabled // false')

    if [[ "${billing_enabled}" == "true" ]]; then
        report_result "Pass"
    else
        report_result "Fail"
        echo "  - Billing is not enabled for project ${PROJECT_ID}." >&2
        echo "  - Please run: gcloud beta billing projects link ${PROJECT_ID} --billing-account <ACCOUNT_ID>" >&2
        exit 1
    fi
}

function enable_services () {
  print_status "Enabling GCP Services..."
  local log_file="enable_services.log"
  if run_gcloud "${log_file}" gcloud services enable \
    dataproc.googleapis.com \
    compute.googleapis.com \
    secretmanager.googleapis.com \
    certificatemanager.googleapis.com \
    networksecurity.googleapis.com \
    networkservices.googleapis.com \
    networkmanagement.googleapis.com \
    privateca.googleapis.com \
    --project=${PROJECT_ID}; then
    report_result "Pass"
  else
    report_result "Fail"
  fi
}

function enable_secret_manager() {
  print_status "Enabling Secret Manager API..."
  local log_file="enable_secret_manager.log"
  if run_gcloud "${log_file}" gcloud services enable \
    secretmanager.googleapis.com \
    --project=${PROJECT_ID}; then
    report_result "Pass"
  else
    report_result "Fail"
  fi
}

function create_secret() {
  local secret_name="${1:-${MYSQL_SECRET_NAME}}"
  print_status "Creating Secret ${secret_name}..."
  local log_file="create_secret_${secret_name}.log"
  if echo -n "super secret" | run_gcloud "${log_file}" gcloud secrets create "${secret_name}" \
    --project="${PROJECT_ID}" \
    --replication-policy="automatic" \
    --data-file=-; then
    report_result "Created"
  else
    report_result "Fail"
  fi
}

function check_image_exists() {
  local image_uri="$1"
  if [[ -z "${image_uri}" || "${image_uri}" == "null" ]]; then
    return 1 # Not found if URI is empty or null
  fi
  # Extracts image name from full URI if necessary
  local image_name=$(basename "${image_uri}")
  gcloud compute images describe "${image_name}" --project="${PROJECT_ID}" > /dev/null 2>&1
}

# Check for any debug VMs
function exists_debug_vms() {
  _check_exists gcloud compute instances list --project="${PROJECT_ID}" --filter='name~^debug-' --format="json(name,zone,status)" | jq 'if . == [] then null else . end'
}
export -f exists_debug_vms

# Check for any VMs in the default network
function exists_any_vms_in_network() {
  local vms=$(gcloud compute instances list --project="${PROJECT_ID}" --filter="networkInterfaces.network ~ /${NETWORK}$" --format="value(name)" 2>/dev/null)
  if [[ -n "${vms}" ]]; then
    echo "true"
  else
    echo "false"
  fi
}
export -f exists_any_vms_in_network

# Get state of any VMs in the default network for audit
function get_any_network_vms_state() {
  _check_exists gcloud compute instances list --project="${PROJECT_ID}" --filter="networkInterfaces.network ~ /${NETWORK}$" --format="json(name,zone,status)" | jq 'if . == [] then null else . end'
}
export -f get_any_network_vms_state
