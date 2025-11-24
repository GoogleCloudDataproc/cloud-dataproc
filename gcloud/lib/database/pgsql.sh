#!/bin/bash
#
# PostgreSQL Cloud SQL functions

function create_pgsql_instance() {
  local phase_name="create_pgsql_instance"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating PostgreSQL Instance ${PGSQL_INSTANCE}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating PostgreSQL Instance ${PGSQL_INSTANCE}..."
  if gcloud sql instances describe "${PGSQL_INSTANCE}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
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
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f create_pgsql_instance

function delete_pgsql_instance() {
  local phase_name="create_pgsql_instance"
  remove_sentinel "${phase_name}" "done"

  print_status "Deleting PostgreSQL Instance ${PGSQL_INSTANCE}..."
  if gcloud sql instances describe "${PGSQL_INSTANCE}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    local log_file="delete_pgsql_${PGSQL_INSTANCE}.log"
    if run_gcloud "${log_file}" gcloud sql instances delete --quiet "${PGSQL_INSTANCE}" --project="${PROJECT_ID}"; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}
export -f delete_pgsql_instance
