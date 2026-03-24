#!/bin/bash

# Exit on failure
set -e

# --- Get script's real directory ---
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
GCLOUD_DIR="$(realpath "${SCRIPT_DIR}/..")"

# --- Source environment variables and utility functions ---
source "${GCLOUD_DIR}/lib/env.sh"

source "${GCLOUD_DIR}/lib/script-utils.sh"
source "${GCLOUD_DIR}/lib/dataproc/cluster.sh"
source "${GCLOUD_DIR}/lib/gcp/misc.sh"

# --- Main Logic ---
configure_gcloud
init_state_db # Initialize the database if it doesn't exist

# Load Stored Configuration from the state DB ---
echo "INFO: Loading configuration from ${STATE_DB}" >&2

export IS_CUSTOM=$(get_state "config.isCustom")
export NAT_EGRESS=$(get_state "config.natEgress")
export SWP_EGRESS=$(get_state "config.swpEgress")

# Apply defaults if not set in state.db
IS_CUSTOM=${IS_CUSTOM:-false}
NAT_EGRESS=${NAT_EGRESS:-true}
SWP_EGRESS=${SWP_EGRESS:-false}

# Export the potentially modified values
export IS_CUSTOM
export NAT_EGRESS
export SWP_EGRESS

echo "INFO: Loaded configuration - IS_CUSTOM=${IS_CUSTOM}, NAT_EGRESS=${NAT_EGRESS}, SWP_EGRESS=${SWP_EGRESS}" >&2

# --- Run an audit to refresh the current state of resources ---
# The audit will use the same TIMESTAMP as defined in env.sh for its own logs
print_status "Auditing environment to refresh state..."
"${GCLOUD_DIR}/bin/audit-dpgce" > /dev/null
report_result "Done"

if (( DEBUG != 0 )); then
  set -x
fi

echo "========================================"
echo "Starting DPGCE Cluster Recreation"
echo "========================================"

print_status "Attempting to ensure any pre-existing cluster named '${CLUSTER_NAME}' is deleted..."
delete_dpgce_cluster
report_result "Done"

# Re-create the cluster based on the loaded config
print_status "Creating cluster ${CLUSTER_NAME}..."
create_dpgce_cluster

# After creation, run audit again to update state file with new resource details
print_status "Running final audit to update cache..."
"${GCLOUD_DIR}/bin/audit-dpgce" > /dev/null
report_result "Done"

echo "========================================"
echo "DPGCE Cluster re-created"
echo "========================================"
