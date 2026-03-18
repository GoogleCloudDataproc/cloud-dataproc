#!/bin/bash
# PHS functions

function create_phs_cluster() {
  local phs_cluster_name="${CLUSTER_NAME}-phs"
  print_status "Creating PHS Cluster ${phs_cluster_name}..."
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
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_phs_cluster

function exists_phs_cluster() {
  local phs_cluster_name="${CLUSTER_NAME}-phs"
  _check_exists gcloud dataproc clusters describe "${phs_cluster_name}" --region="${REGION}" --project="${PROJECT_ID}" --format="json(clusterName,status.state)"
}
export -f exists_phs_cluster

function delete_phs_cluster() {
  local phs_cluster_name="${CLUSTER_NAME}-phs"
  print_status "Deleting PHS Cluster ${phs_cluster_name}..."
  local log_file="delete_phs_cluster_${phs_cluster_name}.log"
  if run_gcloud "${log_file}" gcloud dataproc clusters delete --quiet --region "${REGION}" "${phs_cluster_name}"; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_phs_cluster