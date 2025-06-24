#!/bin/bash
#
# CUJ: Standard Dataproc on GKE Management
#
# This script manages the lifecycle of a standard Dataproc on GKE virtual
# cluster and its underlying GKE cluster foundation.

set -e

function main() {
  local SCRIPT_DIR
  SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
  source "${SCRIPT_DIR}/../../../lib/common.sh"
  load_config

  # --- Define derived resource names ---
  # All resource names are derived from a static prefix. This CUJ is self-contained
  # and requires no specific resource names in env.json.
  local base_name="cuj-gke-standard"
  local gke_cluster_name="${base_name}"
  local virtual_cluster_name="${base_name}-dpgke"

  # --- Helper Functions ---
  # These functions orchestrate calls to the common library.
  function provision_gke_infra() {
    header "Provisioning GKE Cluster for Dataproc: '${gke_cluster_name}'"
    # This library function is idempotent and encapsulates creating the GKE
    # cluster and the 'dataproc' node pool required for Dataproc on GKE.
    create_gke_cluster_for_dataproc "${gke_cluster_name}" "${CONFIG[ZONE]}" "${CONFIG[CUJ_TAG]}"
  }

  function teardown_gke_infra() {
    header "Deleting GKE Cluster: '${gke_cluster_name}'"
    delete_gke_cluster "${gke_cluster_name}" "${CONFIG[ZONE]}"
  }

  function provision_virtual_cluster() {
    header "Creating Dataproc virtual cluster '${virtual_cluster_name}'"
    create_dpgke_virtual_cluster \
      "${virtual_cluster_name}" \
      "${gke_cluster_name}" \
      "${CONFIG[ZONE]}" \
      "${CONFIG[REGION]}" \
      "${CONFIG[SHARED_GCS_BUCKET]}"
  }

  function teardown_virtual_cluster() {
    header "Deleting Dataproc virtual cluster '${virtual_cluster_name}'"
    delete_dpgke_virtual_cluster "${virtual_cluster_name}" "${CONFIG[REGION]}"
  }

  function validate() {
    header "Validating APIs for CUJ: ${base_name}"
    validate_apis "container.googleapis.com" "dataproc.googleapis.com"
  }


  # --- Main command handler ---
  case "$1" in
    up)
      validate
      provision_gke_infra
      provision_virtual_cluster
      ;;
    down)
      confirm "This will delete virtual cluster '${virtual_cluster_name}' AND GKE cluster '${gke_cluster_name}'."
      teardown_virtual_cluster
      teardown_gke_infra
      ;;
    cluster-up)
      validate
      provision_virtual_cluster
      ;;
    cluster-down)
      confirm "This will delete virtual cluster '${virtual_cluster_name}' but leave the GKE cluster."
      teardown_virtual_cluster
      ;;
    cluster-rebuild)
      (teardown_virtual_cluster) || true
      provision_virtual_cluster
      ;;
    validate)
      validate
      ;;
    *)
      echo "Usage: $0 {up|down|cluster-up|cluster-down|cluster-rebuild|validate}"
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
