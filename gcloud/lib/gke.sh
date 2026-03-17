#!/bin/bash
# GKE functions

function create_gke_cluster() {
  print_status "Creating GKE Cluster ${GKE_CLUSTER_NAME}..."
  local log_file="create_gke_cluster_${GKE_CLUSTER_NAME}.log"
  if run_gcloud "${log_file}" gcloud container clusters create "${GKE_CLUSTER_NAME}" \
    --service-account="${GSA}" \
    --workload-pool="${PROJECT_ID}.svc.id.goog" \
    --tags "${TAGS}" \
    --subnetwork "${SUBNET}" \
    --network "${NETWORK}" \
    --zone "${ZONE}" --project="${PROJECT_ID}"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_gke_cluster

function delete_gke_cluster() {
  print_status "Deleting GKE Cluster ${GKE_CLUSTER_NAME}..."
  local log_file="delete_gke_cluster_${GKE_CLUSTER_NAME}.log"
  
  for pn in "${DP_CTRL_POOLNAME}" "${DP_DRIVER_POOLNAME}" "${DP_EXEC_POOLNAME}" ; do
    print_status "  Deleting Node Pool ${pn}..."
    run_gcloud "delete_nodepool_${pn}.log" gcloud container node-pools delete --quiet "${pn}" \
      --zone "${ZONE}" \
      --cluster "${GKE_CLUSTER_NAME}" --project="${PROJECT_ID}" || true
  done

  if run_gcloud "${log_file}" gcloud container clusters delete --quiet "${GKE_CLUSTER_NAME}" \
    --zone "${ZONE}" --project="${PROJECT_ID}"; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_gke_cluster

function create_dpgke_cluster() {
  print_status "Creating DPGKE Cluster ${DPGKE_CLUSTER_NAME}..."
  local log_file="create_dpgke_cluster_${DPGKE_CLUSTER_NAME}.log"
  if run_gcloud "${log_file}" gcloud dataproc clusters gke create "${DPGKE_CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --gke-cluster="${GKE_CLUSTER}" \
    --spark-engine-version=latest \
    --staging-bucket="${BUCKET}" \
    --setup-workload-identity \
    --properties="spark:spark.kubernetes.container.image=${REGION}-docker.pkg.dev/${PROJECT_ID}/dockerfile-dataproc/dockerfile:latest" \
    --pools="name=${DP_CTRL_POOLNAME},roles=default,machineType=e2-standard-4" \
    --pools="name=${DP_DRIVER_POOLNAME},min=1,max=3,roles=spark-driver,machineType=n2-standard-4" \
    --pools="name=${DP_EXEC_POOLNAME},min=1,max=10,roles=spark-executor,machineType=n2-standard-8"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_dpgke_cluster

function delete_dpgke_cluster() {
  print_status "Deleting DPGKE Cluster ${DPGKE_CLUSTER_NAME}..."
  local log_file="delete_dpgke_cluster_${DPGKE_CLUSTER_NAME}.log"
  if run_gcloud "${log_file}" gcloud dataproc clusters delete --quiet "${DPGKE_CLUSTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}"; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_dpgke_cluster

function exists_dpgke_cluster() {
  _check_exists "gcloud dataproc clusters describe '${DPGKE_CLUSTER_NAME}' --region '${REGION}' --project='${PROJECT_ID}' --format='json(clusterName,status.state)'"
}
export -f exists_dpgke_cluster
