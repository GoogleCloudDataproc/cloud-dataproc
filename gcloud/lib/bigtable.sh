#!/bin/bash
# Bigtable functions

function exists_bigtable_instance() {
  BIGTABLE_INSTANCES="$(gcloud bigtable instances list --format=json)"
  JQ_CMD=".[] | select(.name | test(\"${BIGTABLE_INSTANCE}$\"))"
  OUR_INSTANCE=$(echo ${BIGTABLE_INSTANCES} | jq -c "${JQ_CMD}")

  if [[ -z "${OUR_INSTANCE}" ]]; then
    return 1
  else
    return 0
  fi
}
export -f exists_bigtable_instance

function create_bigtable_instance() {
  local phase_name="create_bigtable_instance"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Checking Bigtable Instance ${BIGTABLE_INSTANCE}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating Bigtable Instance ${BIGTABLE_INSTANCE}..."
  if exists_bigtable_instance; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    local log_file="create_bigtable_${BIGTABLE_INSTANCE}.log"
    if run_gcloud "${log_file}" gcloud bigtable instances create ${BIGTABLE_INSTANCE} \
      --display-name "${BIGTABLE_DISPLAY_NAME}" \
      --cluster-config="${BIGTABLE_CLUSTER_CONFIG}"; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f create_bigtable_instance

function delete_bigtable_instance() {
  local phase_name="create_bigtable_instance"
  remove_sentinel "${phase_name}" "done"

  print_status "Deleting Bigtable Instance ${BIGTABLE_INSTANCE}..."
  local log_file="delete_bigtable_${BIGTABLE_INSTANCE}.log"
  if exists_bigtable_instance; then
    if run_gcloud "${log_file}" gcloud bigtable instances delete --quiet ${BIGTABLE_INSTANCE}; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}
export -f delete_bigtable_instance