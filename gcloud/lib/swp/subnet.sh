#!/bin/bash

function create_swp_subnet() {
  local subnet_name="${1:-${SWP_SUBNET}}"
  local region="${2:-${REGION}}"
  local network_name="${3:-${NETWORK}}"
  local range="${4:-${SWP_RANGE}}"
  local phase_name="create_swp_subnet"

  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating SWP Subnet ${subnet_name}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating SWP Subnet ${subnet_name}..."
  if gcloud compute networks subnets describe "${subnet_name}" --region="${region}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    local log_file="create_swp_subnet_${subnet_name}.log"
    if run_gcloud "${log_file}" gcloud compute networks subnets create "${subnet_name}" \
      --project="${PROJECT_ID}" \
      --purpose=REGIONAL_MANAGED_PROXY \
      --role=ACTIVE \
      --region="${region}" \
      --network="${network_name}" \
      --range="${range}"; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f create_swp_subnet

function delete_swp_subnet() {
  local subnet_name="${1:-${SWP_SUBNET}}"
  local region="${2:-${REGION}}"
  local phase_name="create_swp_subnet"

  print_status "Deleting SWP Subnet ${subnet_name}..."
  if gcloud compute networks subnets describe "${subnet_name}" --region="${region}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    local log_file="delete_swp_subnet_${subnet_name}.log"
    if run_gcloud "${log_file}" gcloud compute networks subnets delete "${subnet_name}" --region="${region}" --quiet; then
      report_result "Deleted"
      remove_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
    remove_sentinel "${phase_name}" "done" # Remove sentinel if not found
  fi
}
export -f delete_swp_subnet

function create_private_subnet () {
  local subnet_name="${1:-${PRIVATE_SUBNET}}"
  local region="${2:-${REGION}}"
  local network_name="${3:-${NETWORK}}"
  local range="${4:-${PRIVATE_RANGE}}"
  local phase_name="create_private_subnet"

  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating Private Subnet ${subnet_name}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating Private Subnet ${subnet_name}..."
  if gcloud compute networks subnets describe "${subnet_name}" --region "${REGION}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    local log_file="create_private_subnet_${subnet_name}.log"
    if run_gcloud "${log_file}" gcloud compute networks subnets create "${subnet_name}" \
      --project="${PROJECT_ID}" \
      --network="${network_name}" \
      --range="${range}" \
      --enable-private-ip-google-access \
      --region="${region}" \
      --description="subnet for use with Dataproc cluster ${CLUSTER_NAME}"; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f create_private_subnet

function delete_private_subnet () {
  local subnet_name="${1:-${PRIVATE_SUBNET}}"
  local region="${2:-${REGION}}"
  local phase_name="create_private_subnet"

  print_status "Deleting Private Subnet ${subnet_name}..."
  if gcloud compute networks subnets describe "${subnet_name}" --region "${REGION}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    local log_file="delete_private_subnet_${subnet_name}.log"
    if run_gcloud "${log_file}" gcloud compute networks subnets delete --quiet --region "${REGION}" "${subnet_name}"; then
      report_result "Deleted"
      remove_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
    remove_sentinel "${phase_name}" "done" # Remove sentinel if not found
  fi
}
export -f delete_private_subnet