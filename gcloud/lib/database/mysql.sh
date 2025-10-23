#!/bin/bash
#
# MySQL Cloud SQL functions

function create_mysql_instance() {
  local phase_name="create_mysql_instance"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating MySQL Instance ${MYSQL_INSTANCE}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating MySQL Instance ${MYSQL_INSTANCE}..."
  if gcloud sql instances describe "${MYSQL_INSTANCE}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    local log_file="create_mysql_${MYSQL_INSTANCE}.log"
    if run_gcloud "${log_file}" gcloud sql instances create "${MYSQL_INSTANCE}" \
      --no-assign-ip \
      --project="${PROJECT_ID}" \
      --network="${NETWORK_URI_PARTIAL}" \
      --database-version="${MYSQL_DATABASE_VERSION}" \
      --activation-policy=ALWAYS \
      --zone "${ZONE}"; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f create_mysql_instance

function delete_mysql_instance() {
  local phase_name="create_mysql_instance"
  remove_sentinel "${phase_name}" "done"

  print_status "Deleting MySQL Instance ${MYSQL_INSTANCE}..."
  if gcloud sql instances describe "${MYSQL_INSTANCE}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    local log_file="delete_mysql_${MYSQL_INSTANCE}.log"
    if run_gcloud "${log_file}" gcloud sql instances delete --quiet "${MYSQL_INSTANCE}" --project="${PROJECT_ID}"; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}
export -f delete_mysql_instance
