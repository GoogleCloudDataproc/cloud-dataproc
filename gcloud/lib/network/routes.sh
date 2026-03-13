#!/bin/bash
#
# Route Management Functions

function delete_route() {
  local route_name="$1"
  print_status "Deleting Route ${route_name}..."
  local log_file="delete_route_${route_name}.log"
  if run_gcloud "${log_file}" gcloud compute routes delete --quiet "${route_name}" --project="${PROJECT_ID}"; then
    report_result "Deleted"
  else
    report_result "Fail"
    echo "  - Failed to delete route ${route_name}. Log content:" >&2
    cat "${log_file}" >&2
    return 1
  fi
}
export -f delete_route
