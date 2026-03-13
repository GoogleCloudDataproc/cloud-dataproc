#!/bin/bash
#
# PostgreSQL Cloud SQL functions

function create_pgsql_instance() {
  print_status "Creating PostgreSQL Instance ${PGSQL_INSTANCE}..."
  local log_file="create_pgsql_${PGSQL_INSTANCE}.log"
  if run_gcloud "${log_file}" gcloud sql instances create "${PGSQL_INSTANCE}" \
    --no-assign-ip \
    --project="${PROJECT_ID}" \
    --network="${NETWORK_URI_PARTIAL}" \
    --database-version="${PGSQL_DATABASE_VERSION}" \
    --activation-policy=ALWAYS \
    --root-password="${PGSQL_ROOT_PASSWORD}" \
    --zone "${ZONE}"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_pgsql_instance

function delete_pgsql_instance() {
  print_status "Deleting PostgreSQL Instance ${PGSQL_INSTANCE}..."
  local log_file="delete_pgsql_${PGSQL_INSTANCE}.log"
  if run_gcloud "${log_file}" gcloud sql instances delete --quiet "${PGSQL_INSTANCE}" --project="${PROJECT_ID}"; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_pgsql_instance
