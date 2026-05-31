#!/bin/bash
#
# Bigtable functions

function exists_bigtable_instance() {
    _check_exists gcloud bigtable instances describe "${BIGTABLE_INSTANCE}" --format="json(name,displayName)"
}
export -f exists_bigtable_instance

function create_bigtable_instance() {
  print_status "Creating Bigtable Instance ${BIGTABLE_INSTANCE}..."
  local log_file="create_bigtable_${BIGTABLE_INSTANCE}.log"
  if run_gcloud "${log_file}" gcloud bigtable instances create "${BIGTABLE_INSTANCE}" \
    --display-name="${BIGTABLE_DISPLAY_NAME}" \
    --cluster-config="${BIGTABLE_CLUSTER_CONFIG}"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_bigtable_instance

function delete_bigtable_instance() {
  print_status "Deleting Bigtable Instance ${BIGTABLE_INSTANCE}..."
  local log_file="delete_bigtable_${BIGTABLE_INSTANCE}.log"
  if run_gcloud "${log_file}" gcloud bigtable instances delete --quiet "${BIGTABLE_INSTANCE}"; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_bigtable_instance
