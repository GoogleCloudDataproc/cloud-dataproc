#!/bin/bash
#
# CUJ: GCE Cluster with Secure Web Proxy Egress
#
# This script manages the lifecycle of a Dataproc cluster that is configured
# to use a pre-existing Secure Web Proxy (SWP) instance for all its outbound
# internet traffic.
# It assumes the SWP instance was created by the
# 'gcloud/onboarding/create_swp_instance.sh' script.

set -e

function main() {
  local SCRIPT_DIR
  SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
  source "${SCRIPT_DIR}/../../../lib/common.sh"
  load_config

  # --- Define derived resource names ---
  local base_name="cuj-swp-egress"
  local cluster_name="${base_name}-cluster"
  local network_name="${base_name}-net"
  local subnet_name="${base_name}-subnet"
  local subnet_range="10.30.0.0/24" # A distinct CIDR for this CUJ
  local policy_based_route_name="${base_name}-route"
  local swp_instance_name="${CONFIG[SWP_INSTANCE_NAME]}"

  # --- Helper Functions ---

  function validate() {
    header "Validating prerequisites for SWP Egress CUJ"
    echo "Checking for SWP instance: ${swp_instance_name}..."
    if ! gcloud alpha network-services gateways describe "${swp_instance_name}" --location="${CONFIG[REGION]}" &>/dev/null; then
      echo "ERROR: SWP instance '${swp_instance_name}' not found." >&2
      echo "Please run 'gcloud/onboarding/create_swp_instance.sh' first." >&2
      exit 1
    fi
    echo "Prerequisites met."
  }

  function up() {
    header "Provisioning environment for CUJ: ${base_name}"
    validate
    create_network "${network_name}"
    create_subnet "${network_name}" "${subnet_name}" "${subnet_range}" "${CONFIG[REGION]}" "false"

    # Create a policy-based route to direct traffic to the SWP instance.
    if ! gcloud compute policy-based-routes describe "${policy_based_route_name}" &>/dev/null; then
      echo "Creating policy-based route: ${policy_based_route_name}"
      gcloud compute policy-based-routes create "${policy_based_route_name}" \
        --network="${network_name}" \
        --source-range="${subnet_range}" \
        --destination-range="0.0.0.0/0" \
        --next-hop-ilb-ip="$(gcloud alpha network-services gateways describe "${swp_instance_name}" --location="${CONFIG[REGION]}" --format='value(addresses[0])')" \
        --priority=100
    else
      echo "Policy-based route '${policy_based_route_name}' already exists."
    fi

    create_gce_cluster "${cluster_name}" "${CONFIG[REGION]}" "${subnet_name}" "--tags='${CONFIG[CUJ_TAG]}'"
    echo "Environment for '${base_name}' is UP."
  }

  function down() {
    header "Tearing down environment for CUJ: ${base_name}"
    delete_gce_cluster "${cluster_name}" "${CONFIG[REGION]}"
    if gcloud compute policy-based-routes describe "${policy_based_route_name}" &>/dev/null; then
      echo "Deleting policy-based route: ${policy_based_route_name}"
      gcloud compute policy-based-routes delete "${policy_based_route_name}" --quiet
    else
      echo "Policy-based route '${policy_based_route_name}' not found."
    fi
    delete_network "${network_name}"
    echo "Environment for '${base_name}' is DOWN."
  }

  # --- Main command handler ---
  case "$1" in
    validate) validate ;;
    up) up ;;
    down) confirm "This will delete cluster '${cluster_name}' and its dedicated private network and route." && down ;;
    rebuild) down || true; up ;;
    *)
      echo "Usage: $0 {validate|up|down|rebuild}"
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
