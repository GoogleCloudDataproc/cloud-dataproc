#!/bin/bash
#
# MS SQL Cloud SQL functions

function create_legacy_mssql_instance() {
  print_status "Creating Legacy MSSQL Instance ${MSSQL_INSTANCE}..."
  local log_file="create_legacy_mssql_${MSSQL_INSTANCE}.log"
  local METADATA="kdc-root-passwd=${INIT_ACTIONS_ROOT}/${KDC_ROOT_PASSWD_KEY}.encrypted"
  METADATA="${METADATA},kms-keyring=${KMS_KEYRING}"
  METADATA="${METADATA},kdc-root-passwd-key=${KDC_ROOT_PASSWD_KEY}"
  METADATA="${METADATA},startup-script-url=${INIT_ACTIONS_ROOT}/kdc-server.sh"
  METADATA="${METADATA},service-account-user=${GSA}"
  if run_gcloud "${log_file}" gcloud compute instances create "${MSSQL_INSTANCE}" \
    --zone "${ZONE}" \
    --subnet "${SUBNET}" \
    --service-account="${GSA}" \
    --boot-disk-type pd-ssd \
    --image-family="${MSSQL_IMAGE_FAMILY}" \
    --image-project="${MSSQL_IMAGE_PROJECT}" \
    --machine-type="${MSSQL_MACHINE_TYPE}" \
    --scopes='cloud-platform' \
    --metadata "${METADATA}"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_legacy_mssql_instance

function delete_legacy_mssql_instance() {
  print_status "Deleting Legacy MSSQL Instance ${MSSQL_INSTANCE}..."
  local log_file="delete_legacy_mssql_${MSSQL_INSTANCE}.log"
  if run_gcloud "${log_file}" gcloud compute instances delete "${MSSQL_INSTANCE}" --zone "${ZONE}" --project="${PROJECT_ID}" --quiet; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_legacy_mssql_instance

function create_mssql_instance() {
  print_status "Creating MSSQL Instance ${MSSQL_INSTANCE}..."
  local log_file="create_mssql_${MSSQL_INSTANCE}.log"
  if run_gcloud "${log_file}" gcloud sql instances create "${MSSQL_INSTANCE}" \
    --no-assign-ip \
    --project="${PROJECT_ID}" \
    --network="${NETWORK_URI_PARTIAL}" \
    --database-version="${MSSQL_DATABASE_VERSION}" \
    --activation-policy=ALWAYS \
    --zone "${ZONE}"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_mssql_instance

function delete_mssql_instance() {
  print_status "Deleting MSSQL Instance ${MSSQL_INSTANCE}..."
  local log_file="delete_mssql_${MSSQL_INSTANCE}.log"
  if run_gcloud "${log_file}" gcloud sql instances delete --quiet "${MSSQL_INSTANCE}" --project="${PROJECT_ID}"; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_mssql_instance
