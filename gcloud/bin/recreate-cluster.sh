#!/bin/bash

# Exit on failure
set -e

# --- Get script's real directory ---
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GCLOUD_DIR="$(realpath "${SCRIPT_DIR}/..")"

# --- Source environment variables and utility functions ---
source "${GCLOUD_DIR}/lib/env.sh"
source "${GCLOUD_DIR}/lib/script-utils.sh"
source "${GCLOUD_DIR}/lib/dataproc/cluster.sh"
source "${GCLOUD_DIR}/lib/dataproc/cluster-custom.sh"
source "${GCLOUD_DIR}/lib/dataproc/private-cluster.sh"
source "${GCLOUD_DIR}/lib/gcp/misc.sh"

# --- Argument Parsing ---
IS_CUSTOM=false
IS_PRIVATE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --custom) IS_CUSTOM=true ;;
        --private) IS_PRIVATE=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if (( DEBUG != 0 )); then
  set -x
fi

# --- Main Logic ---
configure_gcloud

echo "========================================"
echo "Starting DPGCE Cluster Recreation"
echo "========================================"

# Attempt to delete the cluster, any errors will be logged by delete_dpgce_cluster
print_status "Attempting to ensure any pre-existing cluster named '${CLUSTER_NAME}' is deleted..."
delete_dpgce_cluster
report_result "Done"

# Re-create the cluster based on the flags provided
if [[ "$IS_PRIVATE" == "true" ]]; then
  create_dpgce_private_cluster "$@"
else
  create_dpgce_cluster "$@"
fi

# After creation, run audit again to update state file with new resource details
"${GCLOUD_DIR}/bin/audit-dpgce" > /dev/null

echo "========================================"
echo "DPGCE Cluster re-created"
echo "========================================"
# Display cluster details
gcloud dataproc clusters describe "${CLUSTER_NAME}" --region="${REGION}" --format=json
