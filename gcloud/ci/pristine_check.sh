#!/bin/bash
#
# Verifies and enforces a pristine state in the project for CUJ testing.
# This script is designed to be run from a CI/CD pipeline.
#
# It finds all resources associated with the CUJ test network and deletes them.
#
# Usage:
#   ./pristine_check.sh           # Cleanup mode: Aggressively deletes resources.
#   ./pristine_check.sh --strict  # Validation mode: Fails if any resources are found.

set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/../lib/common.sh"
load_config

STRICT_MODE=false
if [[ "$1" == "--strict" ]]; then
  STRICT_MODE=true
fi

# Use a temporary file to track leftover resources for the final report.
LEFTOVERS_FILE=$(mktemp)
trap 'rm -f -- "${LEFTOVERS_FILE}"' EXIT

header "Pristine Check running in $([[ "$STRICT_MODE" == true ]] && echo 'STRICT' || echo 'CLEANUP') mode"

# --- Resource Discovery and Cleanup ---

# 1. Dataproc Clusters
# Find any clusters on the target network.
CLUSTERS=$(gcloud dataproc clusters list --region="${CONFIG[REGION]}" --filter="config.gceClusterConfig.networkUri.endsWith(\"/${CONFIG[NETWORK]}\")" --format="value(clusterName)" 2>/dev/null)
if [[ -n "${CLUSTERS}" ]]; then
  echo "Found leftover Dataproc clusters: ${CLUSTERS}" | tee -a "${LEFTOVERS_FILE}"
  if [[ "$STRICT_MODE" == false ]]; then
    echo "Cleaning up..."
    # Run deletions in the background for speed.
    for cluster in ${CLUSTERS}; do
      gcloud dataproc clusters delete --quiet "${cluster}" --region="${CONFIG[REGION]}" &
    done
  fi
fi

# 2. GCE Instances
# Find any instances on the target network that are NOT part of a managed instance group (like a KDC).
INSTANCES=$(gcloud compute instances list --filter="networkInterfaces.network.endsWith(\"/${CONFIG[NETWORK]}\") AND -name~gke-" --format="value(name)" 2>/dev/null)
if [[ -n "${INSTANCES}" ]]; then
  echo "Found leftover GCE instances: ${INSTANCES}" | tee -a "${LEFTOVERS_FILE}"
  if [[ "$STRICT_MODE" == false ]]; then
    echo "Cleaning up..."
    gcloud compute instances delete --quiet ${INSTANCES} &
  fi
fi

# 3. Firewall Rules
# Dataproc auto-creates firewall rules with the network name. We'll find them.
FIREWALL_RULES=$(gcloud compute firewall-rules list --filter="network.endsWith(\"/${CONFIG[NETWORK]}\")" --format="value(name)" 2>/dev/null)
if [[ -n "${FIREWALL_RULES}" ]]; then
  echo "Found leftover Firewall Rules: ${FIREWALL_RULES}" | tee -a "${LEFTOVERS_FILE}"
  if [[ "$STRICT_MODE" == false ]]; then
    echo "Cleaning up..."
    gcloud compute firewall-rules delete --quiet ${FIREWALL_RULES} &
  fi
fi

# Wait for all background cleanup jobs to finish before proceeding to network deletion.
if [[ "$STRICT_MODE" == false ]]; then
  echo "Waiting for resource cleanup to complete..."
  wait
  echo "Cleanup complete."
fi

# 4. VPC Network
# This is the last step, as the network cannot be deleted if resources are using it.
# We will use the function from our library here.
if gcloud compute networks describe "${CONFIG[NETWORK]}" &>/dev/null; then
  echo "Found leftover VPC Network: ${CONFIG[NETWORK]}" | tee -a "${LEFTOVERS_FILE}"
  if [[ "$STRICT_MODE" == false ]]; then
    echo "Cleaning up..."
    # The delete_network_and_subnet function is already quiet and handles non-existence.
    delete_network_and_subnet
  fi
fi


# --- Final Report ---
if [[ -s "${LEFTOVERS_FILE}" ]]; then
  echo "--------------------------------------------------" >&2
  echo "ERROR: Leftover resources were detected:" >&2
  cat "${LEFTOVERS_FILE}" >&2
  echo "--------------------------------------------------" >&2
  if [[ "$STRICT_MODE" == true ]]; then
    echo "STRICT mode failed. The project is not pristine." >&2
    exit 1
  fi
fi

echo "Pristine check complete."
