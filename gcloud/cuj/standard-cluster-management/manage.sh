#!/bin/bash
# CUJ: Standard Dataproc Cluster Management

function main() {
  local SCRIPT_DIR
  SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
  source "${SCRIPT_DIR}/../../lib/common.sh"
  set -e
  load_config

  function validate() {
    header "Validating prerequisites"
    echo "Checking for shared GCS bucket..."
    if ! gsutil -q stat "gs://${CONFIG[SHARED_GCS_BUCKET]}/"; then
      echo "ERROR: Shared GCS bucket 'gs://${CONFIG[SHARED_GCS_BUCKET]}/' not found." >&2
      echo "Please run the script in 'gcloud/onboarding/' first." >&2
      exit 1
    fi
    echo "Prerequisites met."
  }

  function create_cluster() {
    # ---FIX---
    # Add defensive check for required configuration.
    if [[ -z "${CONFIG[CLUSTER_NAME]}" || -z "${CONFIG[REGION]}" || -z "${CONFIG[SUBNET]}" || -z "${CONFIG[CUJ_TAG]}" ]]; then
      echo "ERROR: One or more required keys (CLUSTER_NAME, REGION, SUBNET, CUJ_TAG) are missing from env.json" >&2
      exit 1
    fi
    # ---END FIX---

    echo "Creating Dataproc cluster '${CONFIG[CLUSTER_NAME]}'..."
    set -x
    gcloud dataproc clusters create "${CONFIG[CLUSTER_NAME]}" \
      --region="${CONFIG[REGION]}" \
      --subnet="${CONFIG[SUBNET]}" \
      --tags="${CONFIG[CUJ_TAG]}" \
      --format json
    set +x
  }

  function delete_cluster() {
    if [[ -z "${CONFIG[CLUSTER_NAME]}" || -z "${CONFIG[REGION]}" ]]; then
       echo "ERROR: One or more required keys (CLUSTER_NAME, REGION) are missing from env.json" >&2
       exit 1
    fi
    echo "Deleting Dataproc cluster '${CONFIG[CLUSTER_NAME]}'..."
    if gcloud dataproc clusters describe "${CONFIG[CLUSTER_NAME]}" --region="${CONFIG[REGION]}" &>/dev/null; then
      gcloud dataproc clusters delete --quiet "${CONFIG[CLUSTER_NAME]}" --region="${CONFIG[REGION]}"
    else
      echo "Cluster '${CONFIG[CLUSTER_NAME]}' not found, skipping delete."
    fi
  }

  case "$1" in
    validate)
      validate
      ;;
    up) # Creates the full managed stack for this CUJ
      validate
      create_network_and_subnet
      create_cluster
      ;;
    down) # Deletes the full managed stack for this CUJ
      delete_cluster
      delete_network_and_subnet
      ;;
    cluster-rebuild) # Cycles the cluster, leaves network
      (delete_cluster) || true
      create_cluster
      ;;
    *)
      echo "Usage: $0 {validate|up|down|cluster-rebuild}"
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
