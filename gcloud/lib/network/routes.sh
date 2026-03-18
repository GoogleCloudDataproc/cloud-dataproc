#!/bin/bash
#
function ensure_default_internet_route() {
  print_status "Ensuring default internet route for ${NETWORK}..."
  local log_file="ensure_default_route_${NETWORK}.log"
  if ! gcloud compute routes list --project="${PROJECT_ID}" --filter="network=${NETWORK} AND destRange=0.0.0.0/0 AND nextHopGateway=default-internet-gateway" --format="value(name)" | grep -q .; then
    print_status "  Default internet route not found, creating..."
    if run_gcloud "${log_file}" gcloud compute routes create "default-internet-${NETWORK}" \
      --project="${PROJECT_ID}" \
      --network="${NETWORK}" \
      --destination-range=0.0.0.0/0 \
      --next-hop-gateway=default-internet-gateway \
      --priority=1000; then
      report_result "Created"
    else
      report_result "Fail"
      return 1
    fi
  else
    report_result "Exists"
  fi
}
export -f ensure_default_internet_route

function delete_route() {
  local route_name="$1"
  print_status "Deleting Route ${route_name}..."
  local log_file="delete_route_${route_name}.log"

  # Check if the route exists
  if gcloud compute routes describe "${route_name}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    if run_gcloud "${log_file}" gcloud compute routes delete --quiet "${route_name}" --project="${PROJECT_ID}"; then
      report_result "Deleted"
      refresh_resource_state "routes" "" _check_exists gcloud compute routes list --project="${PROJECT_ID}" --filter="network~/${NETWORK}$" --format="json(name,selfLink)"
    else
      report_result "Fail"
      echo "  - Failed to delete route ${route_name}. Log content:" >&2
      cat "${REPRO_TMPDIR}/${log_file}" >&2
      return 1
    fi
  else
    report_result "Not Found"
  fi
}
export -f delete_route
