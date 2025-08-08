#!/bin/bash
#
# Verifies and enforces a pristine state in the project for CUJ testing
# by finding and deleting all resources tagged with the CUJ_TAG.
#
# This script is designed to be run from a CI/CD pipeline at the beginning
# (in cleanup mode) and at the end (in strict mode) of a test run.
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

# Store leftover resources to report at the end
LEFTOVERS_FILE=$(mktemp)
trap 'rm -f -- "${LEFTOVERS_FILE}"' EXIT

# --- Helper Functions ---

# Generic function to find, report, and optionally delete tagged resources.
# Arguments:
#   $1: The type of resource (for logging purposes, e.g., "Dataproc Clusters")
#   $2: The gcloud command to list resources (e.g., "gcloud dataproc clusters list ...")
#   $3: The gcloud command to delete resources (e.g., "gcloud dataproc clusters delete ...")
function process_resources() {
  local resource_type="$1"
  local list_command="$2"
  local delete_command="$3"

  # The "tr" command handles cases where no resources are found (to avoid errors)
  # and where multiple resources are found (one per line).
  local resources
  resources=$(eval "${list_command}" | tr '\n' ' ' | sed 's/ *$//')

  if [[ -n "${resources}" ]]; then
    echo "Found leftover ${resource_type}: ${resources}" | tee -a "${LEFTOVERS_FILE}"
    if [[ "$STRICT_MODE" == false ]]; then
      echo "Cleaning up ${resource_type}..."
      # Some delete commands need resource name(s) first, others last. We assume last.
      eval "${delete_command} ${resources}" &
    fi
  fi
}

# --- Main Execution ---

header "Pristine Check running in $([[ "$STRICT_MODE" == true ]] && echo 'STRICT' || echo 'CLEANUP') mode"

# Define commands for each resource type. All are filtered by the CUJ_TAG where possible.
LIST_CLUSTERS_CMD="gcloud dataproc clusters list --region='${CONFIG[REGION]}' --filter='config.gceClusterConfig.tags.items=${CONFIG[CUJ_TAG]}' --format='value(clusterName)' 2>/dev/null"
DELETE_CLUSTERS_CMD="gcloud dataproc clusters delete --quiet --region='${CONFIG[REGION]}'"

LIST_INSTANCES_CMD="gcloud compute instances list --filter='tags.items=${CONFIG[CUJ_TAG]}' --format='value(name)' 2>/dev/null"
DELETE_INSTANCES_CMD="gcloud compute instances delete --quiet --zone='${CONFIG[ZONE]}'"

# Routers and Networks cannot be tagged, so we must rely on a naming convention for them.
LIST_ROUTERS_CMD="gcloud compute routers list --filter='name~^cuj-' --format='value(name)' 2>/dev/null"
DELETE_ROUTERS_CMD="gcloud compute routers delete --quiet --region='${CONFIG[REGION]}'"

LIST_FIREWALLS_CMD="gcloud compute firewall-rules list --filter='targetTags.items=${CONFIG[CUJ_TAG]} OR name~^cuj-' --format='value(name)' 2>/dev/null"
DELETE_FIREWALLS_CMD="gcloud compute firewall-rules delete --quiet"

# Process resources that can be deleted in parallel first.
process_resources "Dataproc Clusters" "${LIST_CLUSTERS_CMD}" "${DELETE_CLUSTERS_CMD}"
process_resources "GCE Instances" "${LIST_INSTANCES_CMD}" "${DELETE_INSTANCES_CMD}"
process_resources "Firewall Rules" "${LIST_FIREWALLS_CMD}" "${DELETE_FIREWALLS_CMD}"
process_resources "Cloud Routers" "${LIST_ROUTERS_CMD}" "${DELETE_ROUTERS_CMD}"

if [[ "$STRICT_MODE" == false ]]; then
  echo "Waiting for initial resource cleanup to complete..."
  wait
fi

# Process networks last, as they have dependencies.
LIST_NETWORKS_CMD="gcloud compute networks list --filter='name~^cuj-' --format='value(name)' 2>/dev/null"
DELETE_NETWORKS_CMD="gcloud compute networks delete --quiet"
process_resources "VPC Networks" "${LIST_NETWORKS_CMD}" "${DELETE_NETWORKS_CMD}"

if [[ "$STRICT_MODE" == false ]]; then
  wait
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
  # In non-strict mode, we report but don't fail, assuming the next run will succeed.
fi

echo "Pristine check complete."
