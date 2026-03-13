#!/bin/bash
#
# MySQL Cloud SQL functions

function create_mysql_instance() {
  print_status "Creating MySQL Instance ${MYSQL_INSTANCE}..."
  local log_file="create_mysql_${MYSQL_INSTANCE}.log"
  if run_gcloud "${log_file}" gcloud sql instances create "${MYSQL_INSTANCE}" \
    --no-assign-ip \
    --project="${PROJECT_ID}" \
    --network="${NETWORK_URI_PARTIAL}" \
    --database-version="${MYSQL_DATABASE_VERSION}" \
    --activation-policy=ALWAYS \
    --zone "${ZONE}"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_mysql_instance

function delete_mysql_instance() {
  print_status "Deleting MySQL Instance ${MYSQL_INSTANCE}..."
  local log_file="delete_mysql_${MYSQL_INSTANCE}.log"
  if run_gcloud "${log_file}" gcloud sql instances delete --quiet "${MYSQL_INSTANCE}" --project="${PROJECT_ID}"; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_mysql_instance
