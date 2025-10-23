#!/bin/bash
#
# VPC Peering and IP Allocation functions

function create_ip_allocation () {
  print_status "Creating IP Allocation ${ALLOCATION_NAME}..."
  local log_file="create_ip_alloc_${ALLOCATION_NAME}.log"
  if gcloud compute addresses describe ${ALLOCATION_NAME} --global --project="${PROJECT_ID}" > /dev/null 2>&1; then
    report_result "Exists"
  else
    if run_gcloud "${log_file}" gcloud compute addresses create ${ALLOCATION_NAME} \
      --global \
      --purpose=VPC_PEERING \
      --prefix-length=24 \
      --network=${NETWORK_URI_PARTIAL} \
      --project=${PROJECT_ID}; then
      report_result "Created"
    else
      report_result "Fail"
    fi
  fi
}

function delete_ip_allocation () {
  print_status "Deleting IP Allocation ${ALLOCATION_NAME}..."
  local log_file="delete_ip_alloc_${ALLOCATION_NAME}.log"
  if gcloud compute addresses describe ${ALLOCATION_NAME} --global --project="${PROJECT_ID}" > /dev/null 2>&1; then
    if run_gcloud "${log_file}" gcloud compute addresses delete --quiet --global ${ALLOCATION_NAME}; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}

function create_vpc_peering () {
  print_status "Creating VPC Peering for ${NETWORK}..."
  local log_file="create_peering_${NETWORK}.log"
  # This command doesn't have a simple describe, so we assume creation is needed if not already done.
  # Potentially check list output if more precise idempotency is needed.
  if run_gcloud "${log_file}" gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=${ALLOCATION_NAME} \
    --network=${NETWORK} \
    --project=${PROJECT_ID}; then
    report_result "Created"
  else
    report_result "Fail"
  fi
}

function delete_vpc_peering () {
  print_status "Deleting VPC Peering for ${NETWORK}..."
  local log_file="delete_peering_${NETWORK}.log"
  # Similar to create, delete doesn't have a simple describe check.
  if run_gcloud "${log_file}" gcloud services vpc-peerings delete \
    --service=servicenetworking.googleapis.com \
    --network=${NETWORK} \
    --project=${PROJECT_ID}; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
