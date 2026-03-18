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
    refresh_resource_state "vpcNetwork" "exists_network" "lib/network/network.sh"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_vpc_network

function delete_vpc_network () {
  print_status "Deleting VPC Network ${NETWORK}..."
  local log_file="delete_vpc_${NETWORK}.log"
  if run_gcloud "${log_file}" gcloud compute networks delete --quiet "${NETWORK}" --project="${PROJECT_ID}"; then
    report_result "Deleted"
    update_state "vpcNetwork" "null"
  else
    report_result "Fail"
  fi
}
export -f delete_vpc_network

function delete_all_network_vms() {
  print_status "Deleting all remaining VMs in network ${NETWORK}..."
  local log_file="delete_all_network_vms_${NETWORK}.log"
  local vms=$(gcloud compute instances list --project="${PROJECT_ID}" --filter="networkInterfaces.network ~ /${NETWORK}$" --format="value(NAME,ZONE)" 2>/dev/null)
  if [[ -n "${vms}" ]]; then
    echo "${vms}" | while read -r name zone; do
      print_status "  Deleting VM ${name} in ${zone}..."
      run_gcloud "delete_vm_${name}.log" gcloud compute instances delete "${name}" --zone "${zone}" --quiet || true
    done
    report_result "Done"
  else
    report_result "None Found"
  fi
}
export -f delete_all_network_vms
