#!/bin/bash

function exists_subnet() {
  local subnet_name="$1"
  local region="${2:-${REGION}}"
  _check_exists gcloud compute networks subnets describe "${subnet_name}" --region="${region}" --project="${PROJECT_ID}" --format="json(name,purpose)"
}
export -f exists_subnet

function create_swp_subnet() {
  local subnet_name="${1:-${SWP_SUBNET}}"
  local region="${2:-${REGION}}"
  local network_name="${3:-${NETWORK}}"
  local range="${4:-${SWP_RANGE}}"
  print_status "Creating SWP Subnet ${subnet_name}..."
  local log_file="create_swp_subnet_${subnet_name}.log"
  local cmd=(
    gcloud compute networks subnets create "${subnet_name}"
    --project="${PROJECT_ID}"
    --purpose=REGIONAL_MANAGED_PROXY
    --role=ACTIVE
    --region="${region}"
    --network="${network_name}"
    --range="${range}"
  )
  if run_gcloud "${log_file}" "${cmd[@]}"; then
         report_result "Created"
         refresh_resource_state "swpSubnet" "lib/swp/subnet.sh" exists_subnet "${subnet_name}"
       else
    report_result "Fail"
    return 1
  fi
}
export -f create_swp_subnet

function delete_swp_subnet() {
  local subnet_name="${1:-${SWP_SUBNET}}"
  local region="${2:-${REGION}}"
  print_status "Deleting SWP Subnet ${subnet_name}..."
  local log_file="delete_swp_subnet_${subnet_name}.log"
  if run_gcloud "${log_file}" gcloud compute networks subnets delete "${subnet_name}" --region="${region}" --quiet; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_swp_subnet
