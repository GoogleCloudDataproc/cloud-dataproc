#!/bin/bash
#
# CUJ: GCE Cluster Management with Cloud NAT
#
# This script manages the lifecycle of a standard Dataproc on GCE cluster.
# It creates a dedicated VPC with a Cloud Router and NAT gateway to provide
# internet access for the cluster nodes without requiring public IP addresses.

set -e

function main() {
  local SCRIPT_DIR
  SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
  source "${SCRIPT_DIR}/../../../lib/common.sh"
  load_config

  # --- Define derived resource names ---
  # All resource names are derived from the single top-level name in env.json
  # to simplify configuration.
  local cluster_name="${CONFIG[GCE_CLUSTER_NAME]}"
  local network_name="${cluster_name}-net"
  local subnet_name="${cluster_name}-subnet"
  local router_name="${cluster_name}-router"
  local firewall_prefix="${cluster_name}-fw"

  # --- Helper Functions ---
  # These functions orchestrate calls to the common library.
  function up() {
    header "Provisioning environment for CUJ: ${cluster_name}"
    # The library functions will be idempotent.
    create_network "${network_name}"
    create_subnet "${network_name}" "${subnet_name}" "${CONFIG[GCE_SUBNET_RANGE]}" "${CONFIG[REGION]}"
    create_firewall_rules "${network_name}" "${firewall_prefix}" "${CONFIG[CUJ_TAG]}"
    create_router "${network_name}" "${router_name}" "${CONFIG[REGION]}" "${CONFIG[GCE_ROUTER_ASN]}"
    add_nat_gateway_to_router "${router_name}" "${CONFIG[REGION]}"

    header "Creating Dataproc cluster '${cluster_name}'"
    create_gce_cluster "${cluster_name}" "${subnet_name}" "${CONFIG[REGION]}" "${CONFIG[CUJ_TAG]}"
    echo "Environment for '${cluster_name}' is UP."
  }

  function down() {
    header "Tearing down environment for CUJ: ${cluster_name}"
    # Teardown is in reverse order of creation.
    delete_gce_cluster "${cluster_name}" "${CONFIG[REGION]}"
    # Deleting a router also deletes its NAT gateway.
    delete_router "${router_name}" "${CONFIG[REGION]}"
    delete_firewall_rules "${firewall_prefix}"
    # Deleting a network also deletes its subnets.
    delete_network "${network_name}"
    echo "Environment for '${cluster_name}' is DOWN."
  }

  function validate() {
    header "Validating APIs for CUJ: ${cluster_name}"
    validate_apis "compute.googleapis.com" "dataproc.googleapis.com"
  }


  # --- Main command handler ---
  case "$1" in
    up)
      up
      ;;
    down)
      confirm "This will delete cluster '${cluster_name}' and its entire NATed network environment."
      down
      ;;
    rebuild)
      down || true
      up
      ;;
    validate)
      validate
      ;;
    *)
      echo "Usage: $0 {up|down|rebuild|validate}"
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
