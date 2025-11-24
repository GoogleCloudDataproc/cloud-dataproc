#!/bin/bash
# PHS functions

function create_phs_cluster() {
  local phs_cluster_name="${CLUSTER_NAME}-phs"
  local phase_name="create_phs_cluster"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating PHS Cluster ${phs_cluster_name}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating PHS Cluster ${phs_cluster_name}..."
  if gcloud dataproc clusters describe "${phs_cluster_name}" --region="${REGION}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    local log_file="create_phs_cluster_${phs_cluster_name}.log"
    if run_gcloud "${log_file}" gcloud dataproc clusters create "${phs_cluster_name}" \
      --region="${REGION}" \
      --single-node \
      --image-version="${IMAGE_VERSION}" \
      --subnet="${SUBNET}" \
      --tags="${TAGS}" \
      --properties="spark:spark.history.fs.logDirectory=gs://${PHS_BUCKET},spark:spark.eventLog.dir=gs://${PHS_BUCKET}" \
      --properties="mapred:mapreduce.jobhistory.read-only.dir-pattern=gs://${MR_HISTORY_BUCKET}" \
      --enable-component-gateway; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f create_phs_cluster

function delete_phs_cluster() {
  local phs_cluster_name="${CLUSTER_NAME}-phs"
  local phase_name="create_phs_cluster"
  remove_sentinel "${phase_name}" "done"

  print_status "Deleting PHS Cluster ${phs_cluster_name}..."
  local log_file="delete_phs_cluster_${phs_cluster_name}.log"
  if gcloud dataproc clusters describe "${phs_cluster_name}" --region="${REGION}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    if run_gcloud "${log_file}" gcloud dataproc clusters delete --quiet --region "${REGION}" "${phs_cluster_name}"; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}
export -f delete_phs_cluster