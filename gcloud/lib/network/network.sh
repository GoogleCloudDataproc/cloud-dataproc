#!/bin/bash
#
# VPC Network functions

function create_vpc_network () {
  local phase_name="create_vpc_network"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating VPC Network ${NETWORK}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating VPC Network ${NETWORK}..."
  local log_file="create_vpc_${NETWORK}.log"

  if gcloud compute networks describe "${NETWORK}" --project="${PROJECT_ID}" > /dev/null 2>&1;
 then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    if run_gcloud "${log_file}" gcloud compute networks create "${NETWORK}" \
      --project="${PROJECT_ID}" \
      --subnet-mode=custom \
      --bgp-routing-mode="regional" \
      --description="network for use with Dataproc cluster ${CLUSTER_NAME}"; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}

function delete_vpc_network () {
  print_status "Deleting VPC Network ${NETWORK}..."
  local log_file="delete_vpc_${NETWORK}.log"
  local network_check=$(gcloud compute networks list --project="${PROJECT_ID}" --filter="name = ${NETWORK}" --format="value(name)" 2>/dev/null)

  if [[ -n "${network_check}" ]]; then
    if run_gcloud "${log_file}" gcloud compute networks delete --quiet "${NETWORK}" --project="${PROJECT_ID}"; then
      report_result "Deleted"
      remove_sentinel "create_vpc_network" "done"
    else
      report_result "Fail"
      local dep_log="${REPRO_TMPDIR}/VPC_Network_Delete_Failed_${NETWORK}_${RESOURCE_SUFFIX}.log"
      echo "--- Firewall Rules in ${NETWORK} ---" > "${dep_log}"
      gcloud compute firewall-rules list --project="${PROJECT_ID}" --filter="network ~ ${NETWORK}$" --format="value(name)" >> "${dep_log}" 2>&1
      echo "--- Routes in ${NETWORK} ---" >> "${dep_log}"
      gcloud compute routes list --project="${PROJECT_ID}" --filter="network ~ ${NETWORK}$" --format="value(name, nextHopGateway)" >> "${dep_log}" 2>&1
      echo "--- Routers in ${REGION} ---" >> "${dep_log}"
      gcloud compute routers list --regions="${REGION}" --project="${PROJECT_ID}" --format="value(name, network)" >> "${dep_log}" 2>&1
      echo "--- Subnets in ${NETWORK} ---" >> "${dep_log}"
      gcloud compute networks subnets list --network="${NETWORK}" --project="${PROJECT_ID}" --format="value(name)" >> "${dep_log}" 2>&1
    fi
  else
    report_result "Not Found"
    remove_sentinel "create_vpc_network" "done"
  fi
}
