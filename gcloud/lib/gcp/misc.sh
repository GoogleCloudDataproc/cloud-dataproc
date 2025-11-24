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

function enable_services () {
  local phase_name="enable_services"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Enabling GCP Services..."
    report_result "Exists"
    return 0
  fi

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
    create_sentinel "${phase_name}" "done"
  else
    report_result "Fail"
  fi
}

function enable_secret_manager() {
  local phase_name="enable_secret_manager"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Enabling Secret Manager API..."
    report_result "Exists"
    return 0
  fi

  print_status "Enabling Secret Manager API..."
  local log_file="enable_secret_manager.log"
  if run_gcloud "${log_file}" gcloud services enable \
    secretmanager.googleapis.com \
    --project=${PROJECT_ID}; then
    report_result "Pass"
    create_sentinel "${phase_name}" "done"
  else
    report_result "Fail"
  fi
}

function create_secret() {
  local secret_name="${1:-${MYSQL_SECRET_NAME}}"
  local phase_name="create_secret_${secret_name}"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating Secret ${secret_name}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating Secret ${secret_name}..."
  local log_file="create_secret_${secret_name}.log"
  if gcloud secrets describe "${secret_name}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    if echo -n "super secret" | run_gcloud "${log_file}" gcloud secrets create "${secret_name}" \
      --project="${PROJECT_ID}" \
      --replication-policy=\"automatic\" \
      --data-file=-; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
    fi
  fi
}
