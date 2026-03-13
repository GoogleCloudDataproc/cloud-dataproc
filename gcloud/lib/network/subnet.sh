#!/bin/bash
#
# Subnet functions

function exists_subnet() {
    local subnet_name="$1"
    _check_exists "gcloud compute networks subnets describe '${subnet_name}' --region='${REGION}' --project='${PROJECT_ID}' --format='json(name,selfLink)'"
}

function create_subnet () {
  print_status "Creating Subnet ${SUBNET}..."
  local log_file="create_subnet_${SUBNET}.log"
  if run_gcloud "${log_file}" gcloud compute networks subnets create "${SUBNET}" \
    --project="${PROJECT_ID}" \
    --network="${NETWORK}" \
    --range="${RANGE}" \
    --enable-private-ip-google-access \
    --region="${REGION}" \
    --description="subnet for use with Dataproc cluster ${CLUSTER_NAME}"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}

function delete_subnet () {
  local subnet_name="$1"
  print_status "Deleting Subnet ${subnet_name}..."
  local log_file="delete_subnet_${subnet_name}.log"
  if run_gcloud "${log_file}" gcloud compute networks subnets delete --quiet --region "${REGION}" "${subnet_name}"; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
