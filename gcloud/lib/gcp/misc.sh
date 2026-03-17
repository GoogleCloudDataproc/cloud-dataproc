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

function check_project() {
    print_status "Verifying project ${PROJECT_ID}..."
    local project_state
    project_state=$(jq -r '.project.lifecycleState // "NOT_FOUND"' "${STATE_FILE}")

    if [[ "${project_state}" == "ACTIVE" ]]; then
        report_result "Pass"
    else
        report_result "Fail"
        echo "  - Project ${PROJECT_ID} is not ACTIVE or does not exist (state: ${project_state})." >&2
        exit 1
    fi
}

function check_billing() {
    print_status "Verifying billing for ${PROJECT_ID}..."
    local billing_enabled
    billing_enabled=$(jq -r '.billing.billingEnabled // false' "${STATE_FILE}")

    if [[ "${billing_enabled}" == "true" ]]; then
        report_result "Pass"
    else
        report_result "Fail"
        echo "  - Billing is not enabled for project ${PROJECT_ID} according to state file." >&2
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
  _check_exists "gcloud compute instances list --project='${PROJECT_ID}' --filter='name~^debug-' --format='json(name,zone,status)'" | jq 'if . == [] then null else . end'
}
export -f exists_debug_vms
export -f exists_debug_vms
