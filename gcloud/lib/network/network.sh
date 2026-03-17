#!/bin/bash
#
# VPC Network functions

function exists_network() {
  _check_exists "gcloud compute networks describe '${NETWORK}' --project='${PROJECT_ID}' --format='json(name,selfLink)'"
}
export -f exists_network

function create_vpc_network () {
  print_status "Creating VPC Network ${NETWORK}..."
  local log_file="create_vpc_${NETWORK}.log"
  if run_gcloud "${log_file}" gcloud compute networks create "${NETWORK}" \
    --project="${PROJECT_ID}" \
    --subnet-mode=custom \
    --bgp-routing-mode="regional" \
    --description="network for use with Dataproc cluster ${CLUSTER_NAME}"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}

function delete_vpc_network () {
  print_status "Deleting VPC Network ${NETWORK}..."
  local log_file="delete_vpc_${NETWORK}.log"
  if run_gcloud "${log_file}" gcloud compute networks delete --quiet "${NETWORK}" --project="${PROJECT_ID}"; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
