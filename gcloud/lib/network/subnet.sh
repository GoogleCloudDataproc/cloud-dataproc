#!/bin/bash
#
# Subnet functions

function create_subnet () {
  local phase_name="create_subnet"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating Subnet ${SUBNET}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating Subnet ${SUBNET}..."
  local log_file="create_subnet_${SUBNET}.log"
  if gcloud compute networks subnets describe "${SUBNET}" --region="${REGION}" --project="${PROJECT_ID}" > /dev/null 2>&1;
  then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    if run_gcloud "${log_file}" gcloud compute networks subnets create ${SUBNET} \
      --project="${PROJECT_ID}" \
      --network=${NETWORK} \
      --range="$RANGE" \
      --enable-private-ip-google-access \
      --region=${REGION} \
      --description="subnet for use with Dataproc cluster ${CLUSTER_NAME}"; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}

function delete_subnet () {
  print_status "Deleting Subnet ${SUBNET}..."
  if gcloud compute networks subnets describe "${SUBNET}" --region "${REGION}" > /dev/null 2>&1;
  then
    local log_file="delete_subnet_${SUBNET}.log"
    if run_gcloud "${log_file}" gcloud compute networks subnets delete --quiet --region ${REGION} ${SUBNET}; then
      report_result "Deleted"
      remove_sentinel "create_subnet" "done"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}
