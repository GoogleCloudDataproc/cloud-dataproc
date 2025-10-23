#!/bin/bash
#
# Route functions

function create_default_route() {
  local route_name="default-internet-${NETWORK}"
  print_status "Creating Default Route ${route_name}..."
  local log_file="create_route_${route_name}.log"

  if gcloud compute routes describe "${route_name}" --project="${PROJECT_ID}" > /dev/null 2>&1;
  then
    report_result "Exists"
  else
    if run_gcloud "${log_file}" gcloud compute routes create "${route_name}" \
      --project="${PROJECT_ID}" \
      --network="${NETWORK}" \
      --destination-range=0.0.0.0/0 \
      --next-hop-gateway=default-internet-gateway; then
      report_result "Created"
    else
      report_result "Fail"
    fi
  fi
}

function delete_default_route() {
  local route_name="default-internet-${NETWORK}"
  print_status "Deleting Default Route ${route_name}..."
  if gcloud compute routes describe "${route_name}" --project="${PROJECT_ID}" > /dev/null 2>&1;
  then
    local log_file="delete_route_${route_name}.log"
    if run_gcloud "${log_file}" gcloud compute routes delete --quiet "${route_name}" --project="${PROJECT_ID}"; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}

