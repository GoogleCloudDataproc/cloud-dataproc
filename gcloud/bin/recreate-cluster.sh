#!/bin/bash

# Exit on failure
set -e

# --- Get script's real directory ---
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
GCLOUD_DIR="$(realpath "${SCRIPT_DIR}/..")"

# --- Source environment variables and utility functions ---
source "${GCLOUD_DIR}/lib/env.sh"

# SET TIMESTAMP for THIS run
export TIMESTAMP=$(date +%s)
export REPRO_TMPDIR="/tmp/dataproc-repro/${TIMESTAMP}"
export LOG_DIR="${REPRO_TMPDIR}/logs"
export STATE_DB="${REPRO_TMPDIR}/state.db"
mkdir -p "${REPRO_TMPDIR}"
mkdir -p "${LOG_DIR}"
echo "INFO: Using TIMESTAMP ${TIMESTAMP} for this run." >&2

source "${GCLOUD_DIR}/lib/script-utils.sh"
source "${GCLOUD_DIR}/lib/dataproc/cluster.sh"
source "${GCLOUD_DIR}/lib/gcp/misc.sh"

# --- Main Logic ---
configure_gcloud
init_state_db # Initialize the database for this run

# --- Run an audit to load the current state of other resources ---
print_status "Auditing environment to load state..."
"${GCLOUD_DIR}/bin/audit-dpgce" --timestamp "${TIMESTAMP}" &> /dev/null
report_result "Done"

# --- Load Stored Configuration from last create-dpgce run ---
export IS_CUSTOM=$(get_state "config.isCustom")
export NAT_EGRESS=$(get_state "config.natEgress")
export SWP_EGRESS=$(get_state "config.swpEgress")

# Default to false if not found in DB
IS_CUSTOM=${IS_CUSTOM:-false}
NAT_EGRESS=${NAT_EGRESS:-false}
SWP_EGRESS=${SWP_EGRESS:-false}

echo "INFO: Loaded configuration - IS_CUSTOM=${IS_CUSTOM}, NAT_EGRESS=${NAT_EGRESS}, SWP_EGRESS=${SWP_EGRESS}" >&2

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
"${GCLOUD_DIR}/bin/audit-dpgce" --timestamp "${TIMESTAMP}" &> /dev/null
report_result "Done"

echo "========================================"
echo "DPGCE Cluster re-created"
echo "========================================"